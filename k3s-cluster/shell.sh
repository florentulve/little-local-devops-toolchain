#!/bin/sh
eval $(cat vm.config)
multipass shell ${vm_name}

