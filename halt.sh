#!/bin/sh
cd registry
./stop-registry.sh
cd ..
cd k3s-cluster
./stop-vm.sh
cd ..
cd gitlab
./stop-vm.sh