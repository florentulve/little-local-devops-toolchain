#!/bin/sh
eval $(cat vm.config)
multipass stop ${vm_name}

