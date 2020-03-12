#!/bin/sh

echo "👋 stoping 🐳 registry 🥱"
eval $(cat registry.config)

multipass stop ${registry_name}

