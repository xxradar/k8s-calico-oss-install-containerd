#!/bin/bash
#K8SVERSION is latest ....

sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt update -y

sudo apt install -y \
    watch \
    ipset \
    tcpdump

sudo apt install -y \
          kubeadm \
          kubelet \
          kubectl
          
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Install containerd

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd

# Cluster config
cat >cluster.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    "feature-gates": "SidecarContainers=true"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  serviceSubnet: 10.49.0.0/16
  podSubnet: 192.168.0.0/16
  dnsDomain: cluster.local
  apiserver-cert-extra-sans: 127.0.0.1
apiServer:
  extraArgs:
    "feature-gates": "SidecarContainers=true"
scheduler:
  extraArgs:
    "feature-gates": "SidecarContainers=true"
controllerManager:
  extraArgs:
    "feature-gates": "SidecarContainers=true"
---
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
featureGates:
  SidecarContainers: true
kind: KubeletConfiguration
EOF


kubeadm version
sudo swapoff -a
sudo kubeadm config images pull
sudo kubeadm init --config cluster.yaml
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane
