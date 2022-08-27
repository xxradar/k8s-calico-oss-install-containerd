# Building a K8S install with kubeadm / containerd / calico or cilium

## Create a few nodes
Use at least 4G of RAM / 2 cores and current version of Ubuntu (20.04)
(see branch 

## Initialise kubernetes master mode 
```
curl https://raw.githubusercontent.com/xxradar/install_k8s_ubuntu/main/setup.sh | bash          #K8SVERSION=1.20.4-00
curl https://raw.githubusercontent.com/xxradar/install_k8s_ubuntu/main/setup_latest.sh | bash

```
Note the kubeadm join command, it looks like ...
```
kubeadm join 10.11.2.231:6443 --token eow8gw.8863eelhollpn37p \
    --discovery-token-ca-cert-hash sha256:1e0ec482fcee39edbf6225e6a7e57217bd1e57c23e2d318ef772fae16759947e
```

## Initialise the kubernetes worker nodes
```
curl https://raw.githubusercontent.com/xxradar/install_k8s_ubuntu/main/setup_node.sh | bash         #K8SVERSION=1.20.4-00
curl https://raw.githubusercontent.com/xxradar/install_k8s_ubuntu/main/setup_node_latest.sh | bash

```
Join every nodes by running the `kubeadm join` command
```
kubeadm join 10.11.2.231:6443 --token eow8gw.8863eelhollpn37p \
    --discovery-token-ca-cert-hash sha256:1e0ec482fcee39edbf6225e6a7e57217bd1e57c23e2d318ef772fae16759947e
```

## Install calico or cilium(on master node only)
On the master node, install the calico components
```
curl https://raw.githubusercontent.com/xxradar/install_k8s_ubuntu/main/calico_install.sh | bash
curl https://raw.githubusercontent.com/xxradar/install_k8s_ubuntu/main/cilium_install.sh | bash

```

## Install a demo application 
```
git clone https://github.com/xxradar/app_routable_demo
cd ./app_routable_demo
./setup.sh
```
