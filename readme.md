```
#!/usr/bin/env bash
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt update -y
sudo apt install \
    docker.io \
    watch \
    ipset \
    kubeadm \
    tcpdump -y
sudo systemctl enable docker
sudo docker --version
kubeadm version
sudo swapoff -a
sudo kubeadm config images pull
sudo kubeadm init \
    --pod-network-cidr=192.168.0.0/16 \
    --apiserver-cert-extra-sans=127.0.0.1
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-
```
