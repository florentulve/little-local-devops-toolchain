#!/bin/sh
multipass_state=$(multipass list >/dev/null 2>&1)
if [[ $? -ne 0 ]]; then
    echo "😡 Multipass is not installed"
    exit 1
fi
echo "- multipass ✅"

kubectl_state=$(kubectl >/dev/null 2>&1)
if [[ $? -ne 0 ]]; then
    echo "😡 kubectl is not installed on the host machine"
    exit 1
fi
echo "- kubectl   ✅"

envsubst_state=$(envsubst --version >/dev/null 2>&1)
if [[ $? -ne 0 ]]; then
    echo "😡 envsubst is not installed"
    exit 1
fi
echo "- envsubst  ✅"


git_state=$(git --version >/dev/null 2>&1)
if [[ $? -ne 0 ]]; then
    echo "😡 git is not installed"
    exit 1
fi
echo "- git       ✅"

yq_state=$(yq --version >/dev/null 2>&1)
if [[ $? -ne 0 ]]; then
    echo "😡 yq is not installed"
    exit 1
fi
echo "- yq        ✅"