locals {
  user_data           = <<-EOF
#!/bin/bash

set -x

touch /home/ec2-user/.user-data-started

echo --- install docker ---
dnf update -y
dnf install -y nmap-ncat python3-pip python3 tmux htop git jq # TODO probably only need git
dnf install -y ${var.docker_version}
systemctl enable docker
systemctl start docker
newgrp

echo --- setup gitea ---
docker pull -q ${var.image}
mkdir /etc/gitea /data
mkdir -vp /etc/gitea/gitea/conf/
cat <<EOT > /etc/gitea/gitea/conf/app.ini
${local.app_ini_config}
EOT
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
sed -i s/PUBLIC_IP/$PUBLIC_IP/g /etc/gitea/gitea/conf/app.ini 

echo --- start gitea ---
docker network create gitea
docker run -d \
  --name gitea \
  --network gitea \
  --restart always \
  -e USER_UID=1000 \
  -e USER_GID=1000 \
  -v /etc/gitea:/data \
  -v /etc/timezone:/etc/timezone:ro \
  -v /etc/localtime:/etc/localtime:ro \
  -p ${var.external_port}:3000 \
  -p ${var.ssh_port}:22 \
  ${var.image}

while [ "$(curl -s http://localhost:${var.external_port}/api/healthz | jq -r .status)" != "pass" ]; do sleep 2; done && echo "pass"

echo ---create user ---
docker exec -u git gitea bash -c "/app/gitea/gitea migrate"
docker exec -u git gitea bash -c \
    "/app/gitea/gitea admin user create --username ${var.username} --email ${var.email} --password ${var.password}"

if [ "${var.create_empty_repo}" = true ]; then
  echo --- create emtpy repo ---
  curl -X POST \
    -H "Content-Type: application/json" \
    -u "${var.username}:${var.password}" \
    -d '{"name": "${var.empty_repo_name}", "description": "${var.empty_repo_description}", "private": true}' \
    http://localhost:${var.external_port}/api/v1/user/repos
fi

if [ "${var.create_cloned_repo}" = true ]; then
  echo --- clone repo ---
  ${local.clone_repo_function}
  clone_public_repo_to_gitea \
    "http://${var.username}:${var.password}@$PUBLIC_IP:${var.external_port}" \
    "${var.username}" \
    "$(basename ${var.cloned_repo_source} .git)" \
    "${var.cloned_repo_source}"
fi

if [ "${var.create_secret}" = true ]; then
  echo --- creating secret ---
  curl -X PUT \
    -H "Content-Type: application/json" \
    -H 'accept: application/json' \
    -u "${var.username}:${var.password}" \
    -d '{"data": "${var.secret_value}"}' \
    http://localhost:${var.external_port}/api/v1/user/actions/secrets/${var.secret_name}
fi

if [ "${var.create_runner}" = true ]; then
  echo --- pull runner image ---
  docker pull -q ${var.runner_image} &

  echo --- install runner ---
  curl -sL ${var.runner_binary_url} > /usr/local/bin/act
  chmod +x /usr/local/bin/act

  echo --- create runner config ---
  cat <<EOC > ./runner.yaml
  ${local.runner_config}
EOC

  echo --- register runner ---
  RUNNER_TOKEN=$(docker exec -u git gitea bash -c "/app/gitea/gitea actions generate-runner-token")
  act register --no-interactive --instance http://$PUBLIC_IP:${var.external_port} --token "$RUNNER_TOKEN"

  echo --- start runner ---
  nohup act --config ./runner.yaml daemon &
fi

echo --- gitea setup finished ---
touch /home/ec2-user/.gitea-ready
EOF
  clone_repo_function = <<-EOF
# Bash function to clone a GitHub repository into a new Gitea repository
clone_public_repo_to_gitea() {
  local GITEA_URL="$1"
  local GITEA_USERNAME="$2"
  local GITEA_REPO_NAME="$3"
  local GITHUB_REPO_URL="$4"

  EMAIL="${var.email}"
  NAME="${var.username}"

  # Create a new repo in Gitea
  curl -X POST "$GITEA_URL/api/v1/user/repos" \
  -u "${var.username}:${var.password}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'"$GITEA_REPO_NAME"'",
    "private": false,
    "auto_init": false
  }'

  # Check if the repo creation was successful
  if [ $? -ne 0 ]; then
    echo "Failed to create repository on Gitea"
    return 1
  fi

  cd /tmp

  # Mirror clone the GitHub repository
  git clone "$GITHUB_REPO_URL"
  
  if [ $? -ne 0 ]; then
    echo "Failed to clone GitHub repository"
    return 1
  fi

  # Extract the repo name from the GitHub URL
  local REPO_DIR=$(basename "$GITHUB_REPO_URL" .git)

  # Push to the new Gitea repository
  cd "$REPO_DIR"
  git remote set-url origin "$GITEA_URL/$GITEA_USERNAME/$GITEA_REPO_NAME.git"

  git filter-branch -f --env-filter "GIT_AUTHOR_NAME=$NAME; GIT_AUTHOR_EMAIL=$EMAIL; GIT_COMMITTER_NAME=$NAME; GIT_COMMITTER_EMAIL=$EMAIL;" HEAD
  #git rebase -r --root --exec "git commit --amend --no-edit --reset-author"

  git push # --mirror
  
  if [ $? -ne 0 ]; then
    echo "Failed to push to Gitea repository"
    return 1
  fi

  cd -
  echo "Repository cloned successfully from GitHub to Gitea"
}
EOF
  app_ini_config      = <<-EOF
APP_NAME = Gitea: Git with a cup of tea
RUN_MODE = prod
RUN_USER = git
WORK_PATH = /data/gitea

[repository]
ROOT = /data/git/repositories
DEFAULT_REPO_UNITS = repo.code,repo.releases,repo.issues,repo.pulls,repo.wiki,repo.projects,repo.packages,repo.actions

[repository.local]
LOCAL_COPY_PATH = /data/gitea/tmp/local-repo

[repository.upload]
TEMP_PATH = /data/gitea/uploads

[server]
APP_DATA_PATH = /data/gitea
DOMAIN = PUBLIC_IP
SSH_DOMAIN = PUBLIC_IP
HTTP_PORT = ${var.external_port}
ROOT_URL = http://PUBLIC_IP:${var.external_port}/
DISABLE_SSH = false
SSH_PORT = ${var.ssh_port}
SSH_LISTEN_PORT = 22
LFS_START_SERVER = true
LFS_JWT_SECRET = xqrgNapz38Zox2rfmA32TTdW5Ge1WIgsPUXsykJMIiw
OFFLINE_MODE = false

[database]
PATH = /data/gitea/gitea.db
DB_TYPE = sqlite3
HOST = localhost:3306
NAME = gitea
USER = root
PASSWD = 
LOG_SQL = false
SCHEMA = 
SSL_MODE = disable

[indexer]
ISSUE_INDEXER_PATH = /data/gitea/indexers/issues.bleve

[session]
PROVIDER_CONFIG = /data/gitea/sessions
PROVIDER = file

[picture]
AVATAR_UPLOAD_PATH = /data/gitea/avatars
REPOSITORY_AVATAR_UPLOAD_PATH = /data/gitea/repo-avatars

[attachment]
PATH = /data/gitea/attachments

[log]
MODE = console
LEVEL = info
ROOT_PATH = /data/gitea/log

[security]
INSTALL_LOCK = true
SECRET_KEY = 
REVERSE_PROXY_LIMIT = 1
REVERSE_PROXY_TRUSTED_PROXIES = *
INTERNAL_TOKEN = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYmYiOjE3MTQ5NTYwMTR9.7acb0biC_w1kt80Wd_DimlubtK9PfAOqk542r55JeXA
PASSWORD_HASH_ALGO = pbkdf2

[service]
DISABLE_REGISTRATION = false
REQUIRE_SIGNIN_VIEW = false
REGISTER_EMAIL_CONFIRM = false
ENABLE_NOTIFY_MAIL = false
ALLOW_ONLY_EXTERNAL_REGISTRATION = false
ENABLE_CAPTCHA = false
DEFAULT_KEEP_EMAIL_PRIVATE = false
DEFAULT_ALLOW_CREATE_ORGANIZATION = true
DEFAULT_ENABLE_TIMETRACKING = true
NO_REPLY_ADDRESS = noreply.localhost

[lfs]
PATH = /data/git/lfs

[mailer]
ENABLED = false

[openid]
ENABLE_OPENID_SIGNIN = true
ENABLE_OPENID_SIGNUP = true

[cron.update_checker]
ENABLED = false

[repository.pull-request]
DEFAULT_MERGE_STYLE = merge

[repository.signing]
DEFAULT_TRUST_MODEL = committer

[oauth2]
JWT_SECRET = ${var.jwt_secret}

[actions]
ENABLED=true

[metrics]
ENABLED=true
EOF
  runner_config       = <<-EOF
# Example configuration file, it's safe to copy this as the default config file without any modification.

# You don't have to copy this file to your instance,
# just run `./act_runner generate-config > config.yaml` to generate a config file.

log:
  # The level of logging, can be trace, debug, info, warn, error, fatal
  level: info

runner:
  # Where to store the registration result.
  file: .runner
  # Execute how many tasks concurrently at the same time.
  capacity: 1
  # Extra environment variables to run jobs.
  envs:
    A_TEST_ENV_NAME_1: a_test_env_value_1
    A_TEST_ENV_NAME_2: a_test_env_value_2
  # Extra environment variables to run jobs from a file.
  # It will be ignored if it's empty or the file doesn't exist.
  env_file: .env
  # The timeout for a job to be finished.
  # Please note that the Gitea instance also has a timeout (3h by default) for the job.
  # So the job could be stopped by the Gitea instance if it's timeout is shorter than this.
  timeout: 3h
  # Whether skip verifying the TLS certificate of the Gitea instance.
  insecure: false
  # The timeout for fetching the job from the Gitea instance.
  fetch_timeout: 5s
  # The interval for fetching the job from the Gitea instance.
  fetch_interval: 2s
  # The labels of a runner are used to determine which jobs the runner can run, and how to run them.
  # Like: "macos-arm64:host" or "ubuntu-latest:docker://gitea/runner-images:ubuntu-latest"
  # Find more images provided by Gitea at https://gitea.com/gitea/runner-images .
  # If it's empty when registering, it will ask for inputting labels.
  # If it's empty when execute `daemon`, will use labels in `.runner` file.
  labels:
    - "ubuntu-latest:docker://${var.runner_image}"

cache:
  # Enable cache server to use actions/cache.
  enabled: true
  # The directory to store the cache data.
  # If it's empty, the cache data will be stored in $HOME/.cache/actcache.
  dir: ""
  # The host of the cache server.
  # It's not for the address to listen, but the address to connect from job containers.
  # So 0.0.0.0 is a bad choice, leave it empty to detect automatically.
  host: ""
  # The port of the cache server.
  # 0 means to use a random available port.
  port: 0
  # The external cache server URL. Valid only when enable is true.
  # If it's specified, act_runner will use this URL as the ACTIONS_CACHE_URL rather than start a server by itself.
  # The URL should generally end with "/".
  external_server: ""

container:
  # Specifies the network to which the container will connect.
  # Could be host, bridge or the name of a custom network.
  # If it's empty, act_runner will create a network automatically.
  network: ""
  # Whether to use privileged mode or not when launching task containers (privileged mode is required for Docker-in-Docker).
  privileged: false
  # And other options to be used when the container is started (eg, --add-host=my.gitea.url:host-gateway).
  options:
  # The parent directory of a job's working directory.
  # NOTE: There is no need to add the first '/' of the path as act_runner will add it automatically. 
  # If the path starts with '/', the '/' will be trimmed.
  # For example, if the parent directory is /path/to/my/dir, workdir_parent should be path/to/my/dir
  # If it's empty, /workspace will be used.
  workdir_parent:
  # Volumes (including bind mounts) can be mounted to containers. Glob syntax is supported, see https://github.com/gobwas/glob
  # You can specify multiple volumes. If the sequence is empty, no volumes can be mounted.
  # For example, if you only allow containers to mount the `data` volume and all the json files in `/src`, you should change the config to:
  # valid_volumes:
  #   - data
  #   - /src/*.json
  # If you want to allow any volume, please use the following configuration:
  # valid_volumes:
  #   - '**'
  valid_volumes: []
  # overrides the docker client host with the specified one.
  # If it's empty, act_runner will find an available docker host automatically.
  # If it's "-", act_runner will find an available docker host automatically, but the docker host won't be mounted to the job containers and service containers.
  # If it's not empty or "-", the specified docker host will be used. An error will be returned if it doesn't work.
  docker_host: ""
  # Pull docker image(s) even if already present
  force_pull: true
  # Rebuild docker image(s) even if already present
  force_rebuild: false

host:
  # The parent directory of a job's working directory.
  # If it's empty, $HOME/.cache/act/ will be used.
  workdir_parent:
EOF
}
