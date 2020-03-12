#!/bin/bash
export KUBECONFIG=$PWD/config/k3s.yaml
k9s --all-namespaces 
      
