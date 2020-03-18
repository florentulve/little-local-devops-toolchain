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

Last but not least: every (or some) pod(s) of the cluster should be able to connect to the external registry. Then you need to declare the IP and the domain name to CoreDNS. But there is an annoying bug, every time the cluster re-start, CoreDNS come back with the default settings 😡. See [https://github.com/rancher/k3s/pull/743](https://github.com/rancher/k3s/pull/743)
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

## New project to deploy on K3S

- Use the project you can find in `webapp-sample`. 
- Be sure to use the correct registry (check the Dockerfile too)

**You need to create 2 CI Variables** in your project (or in the group of your project):

- `KUBECONFIG`, define it as a file and use the content of `k3s.yaml` to fill the field
- `CLUSTER_IP`: it's the IP of the Cluster's VM

If you are operating a **Premium** GitLab instance or a **Silver** organisation, you can use the **[Deploy Boards](https://docs.gitlab.com/ee/user/project/deploy_boards.html)** on Kubernetes displaying the status of the pods in the deployment.

To enable the **Deploy Boards** you need to use:

- This variable `KUBE_NAMESPACE`, its content is **generated** by GitLab. The GitLab runner will create a namespace automatically with `KUBE_NAMESPACE` and deploy your application inside this namespace. See [Deployment variables](https://docs.gitlab.com/ee/user/project/clusters/#deployment-variables)
- This 2 kubernetes annotations:
  - `app.gitlab.com/env: $CI_ENVIRONMENT_SLUG`
  - `app.gitlab.com/app: $CI_PROJECT_PATH_SLUG`

The annotations will applied to the deployments, replica sets, and pods.

> - the `KUBE_NAMESPACE`'s format looks like this: `<project_name>-<project_id>-<environment>`
> - `$CI_ENVIRONMENT_SLUG` and `$CI_PROJECT_PATH_SLUG` are the values of the CI variables

### Where to use the annotations?

It's easy. Go to `webapp-sample/kube/deploy.template.yaml` and add the annotations like that in the `Deployment` section:

> for the Deployment
```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APPLICATION_NAME}
  annotations:
    app.gitlab.com/app: ${CI_PROJECT_PATH_SLUG} # here 👋
    app.gitlab.com/env: ${CI_ENVIRONMENT_SLUG}  # here 👋
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APPLICATION_NAME}
  template:
    metadata:
      labels:
        app: ${APPLICATION_NAME}
      annotations:
        app.gitlab.com/app: ${CI_PROJECT_PATH_SLUG} # here 👋
        app.gitlab.com/env: ${CI_ENVIRONMENT_SLUG}  # here 👋
    spec:
      containers:
        - name: ${APPLICATION_NAME}
          image: ${IMAGE}
          ports:
            - containerPort: ${CONTAINER_PORT}
          imagePullPolicy: Always
```

> btw, I already committed the file.

### Deploy the WebApp

If you look at the `.gitlab-ci.yml`, you have all what you need to deploy on `master` or to deploy review application thanks to a MR:

```yaml
stages:
  - 🐳build
  - 🚢deploy

variables:
  REGISTRY: "little-registry.test:5000"
  DOCKER_USER: "little-registry.test:5000"

#----------------------------
# Build Docker image
#----------------------------
📦kaniko-build:
  image:
    name: ${REGISTRY}/gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  stage: 🐳build
  script: |
    IMAGE_NAME="${CI_PROJECT_NAME}-img"
    TAG="${CI_COMMIT_SHORT_SHA}"
    DOCKER_USER="${DOCKER_USER}"
    IMAGE="${DOCKER_USER}/${IMAGE_NAME}:${TAG}"

    echo '{"auths":{"${REGISTRY}":{"username":"","password":""}}}'  > /kaniko/.docker/config.json
    cat /kaniko/.docker/config.json
    
    /kaniko/executor \
    --context $CI_PROJECT_DIR \
    --dockerfile $CI_PROJECT_DIR/Dockerfile \
    --destination ${IMAGE} \
    --insecure --skip-tls-verify --insecure-pull
   
#----------------------------
# Deploy
#----------------------------
#----------------------------
# YAML Anchors
#----------------------------
.environment-variables: &environment-variables
- |
  export CONTAINER_PORT=${CONTAINER_PORT:-8080}
  export EXPOSED_PORT=${EXPOSED_PORT:-80}
  export APPLICATION_NAME=${CI_PROJECT_NAME}
  # 🖐️ KUBE_NAMESPACE is automatically generated by GitLab
  export NAMESPACE=${KUBE_NAMESPACE} 
  export TAG=${CI_COMMIT_SHORT_SHA}
  export IMAGE_NAME="${CI_PROJECT_NAME}-img"
  export DOCKER_USER="${DOCKER_USER}"
  export IMAGE=${DOCKER_USER}/${IMAGE_NAME}:${TAG}
  export CLUSTER_IP="${CLUSTER_IP}"
  export BRANCH=${CI_COMMIT_REF_SLUG}
  export HOST="${APPLICATION_NAME}.${BRANCH}.${CLUSTER_IP}.nip.io"

.environment-variables-substitution: &environment-variables-substitution
- |
  envsubst < ./kube/deploy.template.yaml > ./kube/deploy.${TAG}.yaml
  cat ./kube/deploy.${TAG}.yaml

.kubectl-apply: &kubectl-apply
- |
  kubectl apply -f ./kube/deploy.${TAG}.yaml -n ${NAMESPACE}

.kubectl-scale-by-3: &kubectl-scale-by-3
- |
  kubectl scale --replicas=3 deploy ${APPLICATION_NAME} -n ${NAMESPACE}

.display-information: &display-information
- |
  echo "🌍 http://${HOST}"
  kubectl get pods --namespace ${KUBE_NAMESPACE}


🚀production-deploy:
  stage: 🚢deploy
  image: ${REGISTRY}/k33g/k3g.utilities:1.0.0
  only:
    - master    
  environment:
    name: production/${CI_PROJECT_NAME}-${CI_COMMIT_REF_SLUG}
    url: http://${CI_PROJECT_NAME}.${CI_COMMIT_REF_SLUG}.${CLUSTER_IP}.nip.io
  script:
    - *environment-variables
    - *environment-variables-substitution
    - *kubectl-apply
    - *kubectl-scale-by-3
    - *display-information

🎉preview-deploy:
  stage: 🚢deploy
  image: ${REGISTRY}/k33g/k3g.utilities:1.0.0
  only:
    - branches
  except:
    - master   
  environment:
    name: preview/${CI_PROJECT_NAME}-${CI_COMMIT_REF_SLUG}
    url: http://${CI_PROJECT_NAME}.${CI_COMMIT_REF_SLUG}.${CLUSTER_IP}.nip.io
    on_stop: 😢stop-preview-deploy
  script:
    - *environment-variables
    - *environment-variables-substitution
    - *kubectl-apply
    - *display-information

😢stop-preview-deploy:
  stage: 🚢deploy
  image: ${REGISTRY}/k33g/k3g.utilities:1.0.0
  only:
    - branches
  except:
    - master     
  when: manual    
  environment:
    name: preview/${CI_PROJECT_NAME}-${CI_COMMIT_REF_SLUG}
    action: stop
  script:
    - kubectl delete deploy,service,ingress ${CI_PROJECT_NAME} --namespace=${KUBE_NAMESPACE}
```

Commit and push an update of your application on `master` branch but on a feature branch too, and you'll get all your environments in the dashboard:

![alt k9s](./deploy-board.png)


You will be able to reach your webapp with an URL like this one: http://hello-world.master.192.168.64.27.nip.io/  (`<project-name>.<branch-name>.<cluster IP>.nip.io`)

## How to use SAST Offline with our local toolchain

We have all the necessary tools to operate [Secure scanners offline](https://docs.gitlab.com/ee/user/application_security/offline_deployments/). Let's do it with SAST (the offical documentation is [here](https://docs.gitlab.com/ee/user/application_security/sast/index.html#gitlab-sast-in-an-offline-air-gapped-installation)):

> don't forget to change the values with your own values of course 😉

### First 

Pull the default SAST analyzer images from `registry.gitlab.com` to your local private registry:

```bash
# get the information of the local registry
# content of registry.config:
# registry_name="little-registry";
# registry_domain="little-registry.test";
# registry_port=5000;
eval $(cat registry.config)

function deploy_to_registry() {
  image_name_to_pull=$1
  image_name_to_push=$2
  docker pull ${image_name_to_pull}
  docker tag ${image_name_to_pull} ${registry_domain}:5000/${image_name_to_push}
  docker push ${registry_domain}:5000/${image_name_to_push}
}

deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/bandit:2" "analyzers/bandit:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/brakeman:2" "analyzers/brakeman:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/eslint:2" "analyzers/eslint:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/flawfinder:2" "analyzers/flawfinder:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/go-ast-scanner:2" "analyzers/go-ast-scanner:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/gosec:2" "analyzers/gosec:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/kubesec:2" "analyzers/kubesec:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/nodejs-scan:2" "analyzers/nodejs-scan:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/phpcs-security-audit:2" "analyzers/phpcs-security-audit:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/pmd-apex:2" "analyzers/pmd-apex:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/secrets:2" "analyzers/secrets:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/security-code-scan:2" "analyzers/security-code-scan:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/sobelow:2" "analyzers/sobelow:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/spotbugs:2" "analyzers/spotbugs:2"
deploy_to_registry "registry.gitlab.com/gitlab-org/security-products/analyzers/tslint:2" "analyzers/tslint:2"
```

And just update your `.gitlab-ci.yml` file like that:

- add a stage `😷secure`
- import `SAST.gitlab-ci.yml`
- add a `sast` job

```yaml
stages:
  - 😷secure
  - 🐳build
  - 🚢deploy

variables:
  REGISTRY: "little-registry.test:5000"
  DOCKER_USER: "little-registry.test:5000"

#----------------------------
# Secure
#----------------------------
include:
  - template: SAST.gitlab-ci.yml
  
sast:
  stage: 😷secure
  variables:
    SAST_ANALYZER_IMAGE_PREFIX: "little-registry.test:5000/analyzers"
    SAST_DISABLE_DIND: "true"
    CI_DEBUG_TRACE: "true"
```

> 👋 I added a sample to the repository, look at `webapp-sample-secure`

Now add vulenerabilities to your source code, for example:

```javascript
const AWS_ID = "AKIAIOSFODNN7EXAMPLE"
const AWS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

Commit dnd create a **Merge Request**. Your MR will look like that:

![alt k9s](./merge-request.png)

And your new pipeline:

![alt k9s](./pipeline.png)


That's all 🎉 (for the moment) 😉
