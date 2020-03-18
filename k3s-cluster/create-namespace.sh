#!/bin/bash
export KUBECONFIG=$PWD/config/k3s.yaml
kubectl create namespace $1