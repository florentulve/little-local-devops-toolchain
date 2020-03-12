#!/bin/bash
#eval $(cat cluster.config)
eval $(cat registry.config)
#export KUBECONFIG=$PWD/k3s.yaml

#IP=$(multipass info ${node1_name} | grep IPv4 | awk '{print $2}')

docker pull node:12.0-slim
docker tag node:12.0-slim ${registry_domain}:5000/node:12.0-slim
docker push ${registry_domain}:5000/node:12.0-slim

curl http://${registry_domain}:5000/v2/_catalog
curl http://${registry_domain}:5000/v2/node/tags/list
