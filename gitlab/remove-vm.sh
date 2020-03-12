#!/bin/sh
eval $(cat vm.config)
multipass delete ${vm_name}
multipass purge

rm  workspace/hosts.config
rm  workspace/export.gitlab.config