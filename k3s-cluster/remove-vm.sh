#!/bin/sh
eval $(cat vm.config)
multipass delete ${vm_name}
multipass purge

rm  workspace/hosts.config
rm  workspace/export.cluster.config

rm  config/k3s.yaml

rm  coredns/coredns.patch.yaml
rm  coredns/coredns.yaml

rm  secrets/CA.txt
rm  secrets/TOKEN.txt


#rm secrets/TOKEN.txt
#rm secrets/CA.txt