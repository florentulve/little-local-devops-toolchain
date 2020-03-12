## GitLab

- create root user

> if issue with root user: ref: https://docs.gitlab.com/ee/security/reset_root_password.html
```bash
sudo gitlab-rails console -e production
user = User.where(id: 1).first
user.password = 'secret_pass'
user.password_confirmation = 'secret_pass'
user.save!
```

- go to `http://little-gitlab.test/admin/application_settings/network`
- change **Outbound requests**:
  - `Allow requests to the local network from web hooks and services == true`
  - `Allow requests to the local network from system hooks == true`