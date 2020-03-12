#!/bin/bash
eval $(cat ../workspace/export.cluster.config)
cluster_name=${vm_name}
eval $(cat ../../gitlab/workspace/export.gitlab.config)
gitlab_ip=${vm_ip}
gitlab_domain=${vm_domain}

eval $(cat ../../registry/workspace/export.registry.config)

cp coredns.patch.yaml.template ../coredns/coredns.patch.yaml
sed -i '' "s/REGISTRY_IP/${registry_ip}/" ../coredns/coredns.patch.yaml
sed -i '' "s/REGISTRY_DOMAIN/${registry_domain}/" ../coredns/coredns.patch.yaml

sed -i '' "s/GITLAB_IP/${gitlab_ip}/" ../coredns/coredns.patch.yaml
sed -i '' "s/GITLAB_DOMAIN/${gitlab_domain}/" ../coredns/coredns.patch.yaml

export KUBECONFIG=../config/k3s.yaml

kubectl get configmap coredns -n kube-system -o yaml > ../coredns/coredns.yaml

corefilepatch=$(yq read ../coredns/coredns.patch.yaml  'data.Corefile')

yq delete -i ../coredns/coredns.yaml 'data.Corefile'
yq write -i ../coredns/coredns.yaml 'data.Corefile' "${corefilepatch}"

kubectl apply -f ../coredns/coredns.yaml
kubectl delete pod --selector=k8s-app=kube-dns -n kube-system
