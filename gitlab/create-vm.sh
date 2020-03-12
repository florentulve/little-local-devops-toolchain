#!/bin/sh
eval $(cat vm.config)

multipass launch --name ${vm_name} --cpus 4 --mem 8G --disk 100GB \
	--cloud-init ./cloud-init.yaml


IP=$(multipass info ${vm_name} | grep IPv4 | awk '{print $2}')

echo "👋 Initialize ${vm_name}..."

multipass mount workspace ${vm_name}:workspace

multipass info ${vm_name}

multipass exec ${vm_name}-- sudo -- sh -c "echo \"${IP} ${vm_domain}\" >> /etc/hosts"

multipass --verbose exec ${vm_name} -- sudo -- sh -c "
  apt-get update
  curl -LO https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh
  bash ./script.deb.sh
  EXTERNAL_URL='http://${vm_domain}' apt-get install -y gitlab-ee 
"

# eval $(cat ../registry/workspace/export.registry.config)
# add entry about insecure registry to /etc/hosts
# multipass exec ${vm_name} -- sudo -- sh -c "echo \"${registry_ip} ${registry_domain}\" >> /etc/hosts"

# add entry about insecure registry to /etc/docker/daemon.json
#target="/etc/docker/daemon.json"

#read -r -d '' cmd_insecure << EOM
#	echo "{"  >> ${target}
#	echo '  \"insecure-registries\": [' >> ${target}
#	echo '    \"${registry_domain}:${registry_port}\"' >> ${target}
#	echo '  ]' >> ${target}
#	echo '}' >> ${target}
#	service docker restart
#EOM

#multipass --verbose exec ${vm_name} -- sudo -- sh -c "${cmd_insecure}"

# 🖐 add this to `hosts` file(s)

echo "${IP} ${vm_domain}" > workspace/hosts.config

# 🖐 use this file to exchange data between VM creation script
# use: eval $(cat ../registry/workspace/export.registry.config)
target="workspace/export.gitlab.config"
echo "vm_name=\"${vm_name}\";" >> ${target}
echo "vm_domain=\"${vm_domain}\";" >> ${target}
echo "vm_ip=\"${IP}\";" >> ${target}

