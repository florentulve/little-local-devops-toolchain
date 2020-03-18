#!/bin/bash
eval $(cat registry.config)

function deploy_to_registry() {
  image_name_to_pull=$1
  image_name_to_push=$2
  docker pull ${image_name_to_pull}
  docker tag ${image_name_to_pull} ${registry_domain}:5000/${image_name_to_push}
  docker push ${registry_domain}:5000/${image_name_to_push}
}

#curl http://${registry_domain}:5000/v2/_catalog
#curl http://${registry_domain}:5000/v2/node/tags/list
#curl http://registry.dev.test:5000/v2/gcr.io/kaniko-project/executor/tags/list

# registry.dev.test:5000/gcr.io/kaniko-project/executor:debug


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
