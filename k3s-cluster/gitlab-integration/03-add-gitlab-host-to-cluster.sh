#!/bin/bash
eval $(cat ../workspace/export.cluster.config)
cluster_name=${vm_name}
eval $(cat ../../gitlab/workspace/export.gitlab.config)
gitlab_ip=${vm_ip}
gitlab_domain=${vm_domain}
# add entry about insecure registry to /etc/hosts
multipass exec ${cluster_name} -- sudo -- sh -c "echo \"${gitlab_ip} ${gitlab_domain}\" >> /etc/hosts"

