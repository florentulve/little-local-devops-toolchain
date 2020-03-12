#!/bin/sh
eval $(cat vm.config)


multipass launch --name ${vm_name} --cpus 2 --mem 2G --disk 10GB \
	--cloud-init ./cloud-init.yaml

#IP=$(multipass info ${vm_name} | grep IPv4 | awk '{print $2}')

# Initialize K3s on node
echo "👋 Initialize 📦 K3s on ${vm_name}..."

multipass mount workspace ${vm_name}:workspace
multipass mount secrets ${vm_name}:secrets
multipass mount config ${vm_name}:config

multipass info ${vm_name}

#multipass --verbose exec ${vm_name} -- sudo -- sh -c "
#	echo '👋 hello world 🌍'
#"

multipass exec ${vm_name} -- sudo -- sh -c "echo \"${IP} ${vm_domain}\" >> /etc/hosts"

eval $(cat ../registry/workspace/export.registry.config)
# add entry about insecure registry to /etc/hosts
multipass exec ${vm_name} -- sudo -- sh -c "echo \"${registry_ip} ${registry_domain}\" >> /etc/hosts"

# add entry about insecure registry to /etc/docker/daemon.json
# target="/etc/docker/daemon.json"

#read -r -d '' cmd_insecure << EOM
#	echo "{"  >> ${target}
#	echo '  \"insecure-registries\": [' >> ${target}
#	echo '    \"${registry_domain}:${registry_port}\"' >> ${target}
#	echo '  ]' >> ${target}
#	echo '}' >> ${target}
#	service docker restart
#EOM

#multipass --verbose exec ${vm_name} -- sudo -- sh -c "${cmd_insecure}"

target="/etc/rancher/k3s/registries.yaml"

read -r -d '' cmd_insecure << EOM
	mkdir -p /etc/rancher/k3s
	echo 'mirrors:'  >> ${target}
	echo '  \"${registry_domain}:${registry_port}\":' >> ${target}
	echo '    endpoint:'  >> ${target}
	echo '      - \"http://${registry_domain}:${registry_port}\"' >> ${target}
EOM

multipass --verbose exec ${vm_name} -- sudo -- sh -c "${cmd_insecure}"

# install k3s
multipass --verbose exec ${vm_name} -- sh -c "
	curl -sfL https://get.k3s.io | sh -
"

TOKEN=$(multipass exec ${vm_name} sudo cat /var/lib/rancher/k3s/server/node-token)
IP=$(multipass info ${vm_name} | grep IPv4 | awk '{print $2}')

echo "😃 📦 K3s initialized on ${vm_name} ✅"
echo "🤫 Token: ${TOKEN}"
echo "🖥 IP: ${IP}"


multipass exec ${vm_name} sudo cat /etc/rancher/k3s/k3s.yaml > config/k3s.yaml

sed -i '' "s/127.0.0.1/$IP/" config/k3s.yaml

cp coredns/coredns.patch.yaml.template coredns/coredns.patch.yaml
sed -i '' "s/REGISTRY_IP/${registry_ip}/" coredns/coredns.patch.yaml
sed -i '' "s/REGISTRY_DOMAIN/${registry_domain}/" coredns/coredns.patch.yaml

export KUBECONFIG=$PWD/config/k3s.yaml

kubectl get configmap coredns -n kube-system -o yaml > coredns/coredns.yaml

corefilepatch=$(yq read coredns/coredns.patch.yaml  'data.Corefile')

yq delete -i coredns/coredns.yaml 'data.Corefile'
yq write -i coredns/coredns.yaml 'data.Corefile' "${corefilepatch}"

kubectl apply -f coredns/coredns.yaml
kubectl delete pod --selector=k8s-app=kube-dns -n kube-system

#echo "⏳ give me a moment..."
#sleep 10
#kubectl get nodes
#kubectl top nodes


# 🖐 add this to `hosts` file(s)

echo "${IP} ${vm_domain}" > workspace/hosts.config

# 🖐 use this file to exchange data between VM creation script
# use: eval $(cat ../registry/workspace/export.registry.config)
target="workspace/export.cluster.config"
echo "vm_name=\"${vm_name}\";" >> ${target}
echo "vm_domain=\"${vm_domain}\";" >> ${target}
echo "vm_ip=\"${IP}\";" >> ${target}



