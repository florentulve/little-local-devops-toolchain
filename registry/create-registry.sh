#!/bin/sh
eval $(cat registry.config)

multipass launch --name ${registry_name} --cpus 1 --mem 1G --disk 30GB\
	--cloud-init ./cloud-init.yaml

IP=$(multipass info ${registry_name} | grep IPv4 | awk '{print $2}')

echo "👋 Initialize 🐳 ${registry_name}..."

multipass mount workspace ${registry_name}:workspace
multipass info ${registry_name}

multipass exec ${registry_name} -- sudo -- sh -c "echo \"${IP} ${registry_domain}\" >> /etc/hosts"

# add entry about insecure registry to /etc/docker/daemon.json
target="/etc/docker/daemon.json"

read -r -d '' cmd_insecure << EOM
	echo "{"  >> ${target}
	echo '  \"insecure-registries\": [' >> ${target}
	echo '    \"${registry_domain}:${registry_port}\"' >> ${target}
	echo '  ]' >> ${target}
	echo '}' >> ${target}
	service docker restart
EOM

multipass --verbose exec ${registry_name} -- sudo -- sh -c "${cmd_insecure}"


multipass --verbose exec ${registry_name} -- sudo -- sh -c "
  docker run -d -p 5000:5000 --restart=always --name registry registry:2
"

# run this after every start of the registry
multipass --verbose exec ${registry_name} -- sudo -- sh -c "
  usermod -a -G docker ubuntu
  chmod 666 /var/run/docker.sock
  docker start registry
"

# 🖐 use this file to exchange data between VM creation script
# use: eval $(cat ../registry/workspace/export.registry.config)
target="workspace/export.registry.config"
echo "registry_name=\"${registry_name}\";" >> ${target}
echo "registry_domain=\"${registry_domain}\";" >> ${target}
echo "registry_port=${registry_port};" >> ${target}
echo "registry_ip=\"${IP}\";" >> ${target}

# 🖐 add this to `hosts` file(s)
echo "${IP} ${registry_domain}" > workspace/hosts.config

# 🖐️ add this to `/etc/docker/daemon.json` on every VM with a docker client
target="workspace/etc.docker.daemon.json"
echo '{'  >> ${target}
echo '  "insecure-registries": [' >> ${target}
echo "    \"${registry_domain}:${registry_port}\"" >> ${target}
echo '  ]' >> ${target}
echo '}' >> ${target}

# 🖐️ update `/etc/rancher/k3s/registries.yaml` on every node:
target="workspace/etc.rancher.k3s.registries.yaml"
echo 'mirrors:' >> ${target}
echo "  \"${registry_domain}:${registry_port}\":" >> ${target}
echo '    endpoint:' >> ${target}
echo "      - \"http://${registry_domain}:${registry_port}\"" >> ${target}

# pull and push some Docker images
#read -r -d '' cmd_node_image << EOM
#docker pull node:12.0-slim
#docker tag node:12.0-slim ${registry_domain}:${registry_port}/node:12.0-slim
#docker push ${registry_domain}:${registry_port}/node:12.0-slim
#EOM
#multipass --verbose exec ${registry_name} -- sudo -- sh -c "${cmd_node_image}"






