#!/usr/bin/env bash
set -euo pipefail

K8S_MINOR="${K8S_MINOR:-v1.35}"              # e.g. v1.35
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"        # Calico default
CALICO_VERSION="${CALICO_VERSION:-v3.31.4}"   # Known-good recent Calico
ALLOW_CGROUP_V1="${ALLOW_CGROUP_V1:-0}"       # 0 recommended, 1 = legacy escape hatch

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo -E $0"
  exit 1
fi

echo "[1/8] Basic deps"
apt-get update -y
apt-get install -y ca-certificates curl gpg lsb-release apt-transport-https jq ipset tcpdump

echo "[2/8] Kernel modules + sysctl"
cat >/etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF
modprobe overlay || true
modprobe br_netfilter || true

cat >/etc/sysctl.d/99-kubernetes-cri.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "[3/8] Disable swap"
swapoff -a || true
# Comment out swap in fstab (safe-ish for typical Ubuntu cloud images)
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab || true

echo "[4/8] Check cgroups mode"
CGFS="$(stat -fc %T /sys/fs/cgroup || true)"
if [[ "$CGFS" != "cgroup2fs" ]]; then
  echo "Detected cgroups v1 (stat shows: $CGFS). Kubernetes ${K8S_MINOR} will fail by default on cgroups v1."
  if [[ "$ALLOW_CGROUP_V1" != "1" ]]; then
    cat <<'MSG'

Recommended fix: migrate this host to cgroups v2, then rerun the script.
Typical Ubuntu/GRUB approach:
  1) Edit /etc/default/grub and add:
       systemd.unified_cgroup_hierarchy=1 cgroup_no_v1=all
  2) sudo update-grub
  3) sudo reboot

If you really want the temporary legacy workaround, rerun with:
  sudo -E ALLOW_CGROUP_V1=1 ./setup_latest.sh
MSG
    exit 2
  fi
  echo "ALLOW_CGROUP_V1=1 set, continuing with legacy kubelet config override (not recommended)."
fi

echo "[5/8] Install containerd (Docker repo)"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  >/etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y containerd.io

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl daemon-reload
systemctl enable --now containerd
systemctl restart containerd

echo "[6/8] Install Kubernetes packages (${K8S_MINOR})"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  >/etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet

echo "[7/8] kubeadm init"
kubeadm config images pull || true

KUBEADM_ARGS=(init
  --pod-network-cidr="${POD_CIDR}"
  --apiserver-cert-extra-sans=127.0.0.1
  --cri-socket=unix:///run/containerd/containerd.sock
)

if [[ "$CGFS" != "cgroup2fs" ]]; then
  cat >/root/kubeadm-config.yaml <<'YAML'
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
FailCgroupV1: false
YAML

  kubeadm init --config /root/kubeadm-config.yaml --ignore-preflight-errors=SystemVerification "${KUBEADM_ARGS[@]:1}"
else
  kubeadm "${KUBEADM_ARGS[@]}"
fi

echo "[8/8] kubeconfig + allow scheduling on single node + CNI"
export KUBECONFIG=/etc/kubernetes/admin.conf

# Put kubeconfig in the invoking user's home too (if any)
TARGET_USER="${SUDO_USER:-root}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 || echo /root)"
mkdir -p "${TARGET_HOME}/.kube"
cp -f /etc/kubernetes/admin.conf "${TARGET_HOME}/.kube/config"
chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.kube" || true

# Remove control-plane taint (single-node convenience)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true

# Install Calico
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

echo "Done. Check:"
echo "  kubectl get nodes -o wide"
echo "  kubectl get pods -A"
