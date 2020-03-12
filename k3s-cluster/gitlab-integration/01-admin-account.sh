#!/bin/bash
export KUBECONFIG=../config/k3s.yaml
      
kubectl apply -f gitlab-admin-service-account.yaml