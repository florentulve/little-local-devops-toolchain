#!/bin/sh
eval $(cat registry.config)
multipass shell ${registry_name}

