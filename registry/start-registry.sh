#!/bin/sh
echo "👋 starting 🐳 registry 🚀"
eval $(cat registry.config)

multipass start ${registry_name}

multipass --verbose exec ${registry_name} -- sudo -- sh -c "
  usermod -a -G docker ubuntu
  chmod 666 /var/run/docker.sock
  docker start registry
"

multipass info ${registry_name}
