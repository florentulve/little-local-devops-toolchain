#!/bin/sh
cd registry
./start-registry.sh
cd ..
cd k3s-cluster
./start-vm.sh
cd ..
cd gitlab
./start-vm.sh