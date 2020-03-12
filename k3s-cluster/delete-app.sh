#!/bin/bash
export KUBECONFIG=$PWD/config/k3s.yaml
deployment_name=$1
namespace=$2

kubectl delete deploy,service,ingress ${deployment_name} --namespace="${namespace}"

#kubectl delete deploy hello --namespace="training"
#kubectl delete deploy,service registry --namespace="tools"