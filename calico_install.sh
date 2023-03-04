#!/usr/bin/env bash

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.5/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/v3.24.5/manifests/custom-resources.yaml -O
sed -i 's/#   value: "192.168.0.0\/16"/  value: "192.168.0.0\/20"/g' custom-resources.yaml
kubectl apply -f ./custom-resources.yaml

