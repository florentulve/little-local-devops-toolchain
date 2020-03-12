## GitLab Kube integration

> host side:
```bash 
cd k3s-cluster/gitlab-integration
./01-admin-account.sh
./02-get-certificate-token.sh
./03-add-gitlab-host-to-cluster.sh
./04-patch-core-dns.sh
```

👋 the certificate and the token are generated in `k3s-cluster/secrets`

go to your GitLab UI in the admin panel:

- http://little-gitlab.test/admin/clusters/new
- add an existing cluster
- cluster name: `little-cluster`
- API URL: `https://192.168.64.27:6443` (check the ip of your cluster, you can find the appropriate url in this file: `k3s.yaml`)
- set the CA
- set the Token
- click on **"Install Helm Tiller"**
- click on **"Install Gitlab Runner"**


