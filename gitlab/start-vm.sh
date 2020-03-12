#!/bin/sh
eval $(cat vm.config)
multipass start ${vm_name}
#multipass mount workspace ${vm_name}:workspace
multipass info ${vm_name}
