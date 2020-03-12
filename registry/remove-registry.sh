#!/bin/sh
echo "👋 deleting 🐳 registry 😢"
eval $(cat registry.config)

multipass delete ${registry_name}
multipass purge

rm  workspace/etc.docker.daemon.json
rm  workspace/etc.rancher.k3s.registries.yaml
rm  workspace/hosts.config
rm  workspace/export.registry.config