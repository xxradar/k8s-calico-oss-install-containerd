# Automating a K8S install with kubeadm / containerd / calico

## Initialise kubernetes master mode 
```
curl https://raw.githubusercontent.com/xxradar/install_k8s_ubuntu/main/setup.sh | bash
```
Note the kubeadm join command ... 

## Initialise the kubernetes worker nodes
```
curl https://raw.githubusercontent.com/xxradar/install_k8s_ubuntu/main/setup_node.sh | bash
```
Join the nodes ...

## Install calico
```
curl https://raw.githubusercontent.com/xxradar/install_k8s_ubuntu/main/setup_node.sh | bash
```

