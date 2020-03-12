# Little Local DevOps ToolChain
First, here is the context: I'm working at GitLab as Technical Account Manager (my duty is to help the customers and make the glue between them and GitLab). To understand things, I need to try these things "in real". So, I remember my first task when I started at GitLab; I decided to install GitLab inside a Virtual Machine, and now for two years, I learned a lot of new things, and my use cases and demos became more complicated 😉.

My last use case is the following:
- I need a toolchain that runs locally (on my laptop)
- I want to deploy web-applications from GitLab CI to Kubernetes

The main components of my little toolchain are:
- a private insecure Docker registry in a VM
- a Kubernetes cluster (mono node) in a VM
- a GitLab instance in a VM
- a GitLab Runner deployed on Kubernetes (aka Kubernetes executor)
- I will use K3S from Rancher as Kubernetes distribution, and Multipass from Canonical to create the virtual machines.

My target workflow of CI/CD will be the following:
- The source code of the web-application is on GitLab
- When I commit something on the project:
- The build of the image container is done with Kaniko (to avoid DIND)
- Once the build is done, the application is deployed on K3S thanks to kubectl (and GitLab CI of course and the Kubernetes executor)

I scripted all the steps and will explain how to use all scripts, but first of all, these are the requirements to be able to run the scrips. You need to install:
- Multipass (https://multipass.run/)
- yq (like jq but for YAML) (https://github.com/mikefarah/yq)
- kubectl (CLI of Kubernetes) (https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- git
- Docker
- K9S (optional but extremely useful) (https://github.com/derailed/k9s)

👋 **Remarks**: I did all my test on OSX (theoretically it should work on Linux, and I plan to test it on Linux shortly. About Windows ... 🤔 nothing planned yet - sorry for that)

🍻 **A big thanks to [Louis Tournayre](https://twitter.com/_louidji)**, who taught me a lot of things about Kubernetes.

Now, it's time to start.

## Clone the repository "little local devosp toolchain"

The first step id to git clone this project: https://gitlab.com/k33g/little-local-devops-toolchain (`git clone git@gitlab.com:k33g/little-local-devops-toolchain.git`)

## Create the Docker Registry

If you want to change the name of the VM, the domain name of the registry, you can update this file: `/registry/registry.config`

Then, type the following commands:

```bash
cd registry
./create-registry.sh
```
and wait a little moment.

When the registry is ready, you need to do some manual tasks if you want to be able to use it from the computer host.
The script has created some files in the `workspace` directory. These files will be used in the next steps when we'll create the other VMs.

Right now, you can use the content of `workspace/hosts.config` to update the content of your `hosts` file. You should find an entry like that:
```
192.168.64.26 little-registry.test
```

Next, you must tell your Docker client that you will use an insecure registry. For that, you can use the content of `workspace/etc.docker.daemon.json`:
```json
{
  "insecure-registries": [
    "little-registry.test:5000"
  ]
}
```
You can add the entry with the settings panels of your Docker client or with updating this file: `/etc/docker/daemon.json`. In both cases, you need to restart the Docker client.

And now you can check if your Docker registry is OK, pushing some docker image to the registry. Stay in the `registry` directory and type:

```bash 
registry_domain="little-registry.test"
docker pull node:12.0-slim
docker tag node:12.0-slim ${registry_domain}:5000/node:12.0-slim
docker push ${registry_domain}:5000/node:12.0-slim
```

And when the image is pulled from the Docker Hub and pushed to your repository, type:

```bash
curl http://${registry_domain}:5000/v2/_catalog 
```
You should get:
```
{"repositories":["node"]}
```

Now, if you want to stop the registry (the VM of the registry) type:
```bash
cd registry
./stop-registry.sh
```

If you want to start the registry, type:
```bash
cd registry
./start-registry.sh
```

> for every VM creation, the number of CPU, RAM and disk size are hardcoded in the scripts (it will change in a next version)

## Create the mono K3S cluster

If you want to change the name of the VM, the domain name of the cluster, you can update this file: `/k3s-cluster/vm.config`.

Now, to create the cluster, run this:

```bash
cd k3s-cluster
./create-vm.sh
```

The script will create a mono cluster. It will use the files generated by the registry creation to add several entries to the VM and the cluster:

It will add `192.168.64.26 little-registry.test` to the  `hosts` file of the VM

It will declare the registry as an insecure registry in `/etc/rancher/k3s/registries.yaml`, now the cluster will understand that it can use the registry (you should update or create this on every node of the cluster and restart every node).

The content of the entry looks like that:
```
mirrors:
  "little-registry.test:5000":
    endpoint:
      - "http://little-registry.test:5000"
```

Then, the script will install K3S inside the VM. After that, the script will copy the configuration file of the cluster to `/config/k3s.yaml`. This file is essential, and you will use it with the `kubectl` CLI to communicate with the cluster.

Last but not least: every (or some) pod(s) of the cluster should be able to connect to the external registry. Then you need to declare the IP and the domain name to CoreDNS. But there is an annoying bug, every time the cluster re-start, CoreDNS come back with the default settings 😡.
It's why I created a script (used when creating and at every start) that will get the **configmap** of CoreDNS and update it with the needed information and will recreate the CoreDNS pod.

If you want to add other services, add an entry to `/coredns/coredns.patch.yaml` after the registry entry (this file is generated one time at the VM creation) and restart the cluster.

👋 **Advice**: install K9S to manage your cluster (it's a text console management)

To run K9S, type:
```bash
cd k3s-cluster
export KUBECONFIG=$PWD/config/k3s.yaml
k9s --all-namespaces 
``` 

## Create the GitLab instance

As for the previous VM, if you want to change the name of the VM, the domain name of the cluster, you can update this file: `/gitlab/vm.config`, and type:

```
cd gitlab
./create-vm.sh
```

Once the instance installed, you have to add the entry of GitLab to your `hosts` file, something like that: `192.168.64.28 little-gitlab.test`.
You can check this file to get the appropriate entry: `gitlab/workspace/hosts.config`.

Now you need to achieve some tasks before deploying to Kube. First, connect to http://little-gitlab.test to create the root user. Then, go to the admin panel and:
deactivate AutoDevops (go to `/admin/application_settings/ci_cd`)
allow all request to the local network (go to `/admin/application_settings/network` and to the Outbound requests part)
Now, it's time to set up the Kubernetes integration.

## Deploy a GitLab runner to Kubernetes

Return to this directory: `k3s-cluster/gitlab-integration` and:

- run `./01-admin-account.sh` to create a GitLab account inside the cluster
- run `./02-get-certificate-token.sh` to generate the certificate and the token you will need to declare the cluster inside GitLab. The two files will be generated in the sub-directory `/secrets`
- run `./03-add-gitlab-host-to-cluster.sh` to add the GitLab entry to the Cluster's VM
- run `./04-patch-core-dns.sh` to "patch" again the configmap of CoreDNS (making GitLab reachable from the cluster)

Now, return to http://little-gitlab.test/, and in the admin section go to the Kubernetes section (`/admin/clusters`), click on **Add Kubernetes cluster**, choose **Add existing cluster** and fill the fields like that:

- **Kubernetes cluster name**: little-cluster (or what you want)
- **API URL**: https://192.168.64.27:6443 (you can find the appropriate value in the `k3s.yaml` file
- **CA Certificate**: use the content of `secrets/CA.txt`
- **Service Token**: use the content of `secrets/TOKEN.txt`

And then, click on **"Add Kubernetes cluster"**

On the next screen, 
- Click on **"Install"** at the **"Helm Tiller"** section (you can follow the progress from K9S console)
- Once, Helm Tiller installed, click on **"Install"** at the **"GitLab Runner"** section (you can follow the progress from K9S console)
- Once the installation of the runner is finished, you can check if the runner is correctly registered by reaching the runner's section of the administration console (/admin/runners).

Now, you're almost ready to deploy from Kubernetes from GitLab.

## Add some tools to the registry

To avoid the use of Docker in Docker, we'll use Kaniko to build our container's images. For that, we need to type theses commands:

```bash
cd registry
./deploy-kaniko-to-registry.sh
```

After, we'll need **kubectl** (and perhaps **helm**) to deploy to Kubernetes from GitLab. For that, I prepared a Docker image with these tools (the source is here: https://gitlab.com/k3g/tools/k3g.utilities), and type these commands to push it to our local registry:

```bash
cd registry
./deploy-k33g-utilities-to-registry.sh
```

Now, we are ready to create and deploy our first project.

## New project

- Use the project you can find in `webapp-sample`. 
- Be sure to use the correct registry (check the Dockerfile too)

You need to create 2 CI Variables in your project (or in the group of your project):

- `KUBECONFIG`, define it as a file and use the content of `k3s.yaml` to fill the field
- `CLUSTER_IP`: it's the IP of the Cluster's VM

Launch the CI script, and soon you will be able to reach your webapp with an URL like this one: http://hello-world.master.192.168.64.27.nip.io/ 
(`<project-name>.<branch-name>.<cluster IP>.nip.io`)

That's all 🎉 (for the moment) 😉
