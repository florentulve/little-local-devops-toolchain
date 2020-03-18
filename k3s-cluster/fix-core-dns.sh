#!/bin/sh
eval $(cat vm.config)

export KUBECONFIG=$PWD/config/k3s.yaml
rm coredns/coredns.yaml

kubectl get configmap coredns -n kube-system -o yaml > coredns/coredns.yaml

corefilepatch=$(yq read coredns/coredns.patch.yaml  'data.Corefile')

yq delete -i coredns/coredns.yaml 'data.Corefile'
yq write -i coredns/coredns.yaml 'data.Corefile' "${corefilepatch}"

kubectl apply -f coredns/coredns.yaml
kubectl delete pod --selector=k8s-app=kube-dns -n kube-system
