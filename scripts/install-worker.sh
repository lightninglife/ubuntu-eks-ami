#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
IFS=$'\n\t'
export AWS_DEFAULT_OUTPUT="json"

# Define the path to the daemon.json file
daemon_json_file="/etc/docker/daemon.json"

# Define the path for the logrotate configuration file
logrotate_config="/etc/logrotate.d/kube-proxy"

# Set variables
KUBECONFIG_FILE="/var/lib/kubelet/kubeconfig"
IAM_AUTHENTICATOR="/usr/bin/aws-iam-authenticator"

# Bootstrap file
BOOTSTRAP="scripts/bootstrap.sh"

# Ubuntu server variables
OS="xUbuntu_22.04"
VERSION="1.28"

################################################################################
### Validate Required Arguments ################################################
################################################################################
validate_env_set() {
  (
    set +o nounset

    if [ -z "${!1}" ]; then
      echo "Packer variable '${1:-}' was not set. Aborting"
      exit 1
    fi
  )
}

validate_env_set BINARY_BUCKET_NAME
validate_env_set BINARY_BUCKET_REGION
validate_env_set DOCKER_VERSION
validate_env_set CONTAINERD_VERSION
validate_env_set RUNC_VERSION
validate_env_set CNI_PLUGIN_VERSION
validate_env_set KUBERNETES_VERSION
validate_env_set KUBERNETES_BUILD_DATE
validate_env_set PULL_CNI_FROM_GITHUB
validate_env_set PAUSE_CONTAINER_VERSION
validate_env_set CACHE_CONTAINER_IMAGES
validate_env_set WORKING_DIR

################################################################################
### Machine Architecture #######################################################
################################################################################

MACHINE=$(uname -m)
if [ "$MACHINE" == "x86_64" ]; then
  ARCH="amd64"
elif [ "$MACHINE" == "aarch64" ]; then
  ARCH="arm64"
else
  echo "Unknown machine architecture '$MACHINE'" >&2
  exit 1
fi

################################################################################
### Packages ###################################################################
################################################################################

# Update the OS to begin with to catch up to the latest packages.
set -ex
sudo DEBIAN_FRONTEND=noninteractive apt update -y


sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  apt-utils 

# install unzip
if ! [ -x "$(command -v unzip)" ]; then
    echo "Installing unzip..."
    set -x
    sudo DEBIAN_FRONTEND=noninteractive apt install unzip -y
    echo "unzip installed."
else
    echo "unzip is already installed."
fi


# Define isolated regions
ISOLATED_REGIONS="${ISOLATED_REGIONS:-us-iso-east-1 us-iso-west-1 us-isob-east-1}"

# Check if the AWS CLI needs to be installed based on region
if ! [[ ${ISOLATED_REGIONS} =~ $BINARY_BUCKET_REGION ]]; then
  # Install AWS CLI version 2 bundle
  echo "Installing awscli v2 bundle"
  curl \
    --silent \
    --show-error \
    --retry 10 \
    --retry-delay 1 \
    -L "https://awscli.amazonaws.com/awscli-exe-linux-${MACHINE}.zip" -o "/tmp/awscliv2.zip"
  unzip -q "/tmp/awscliv2.zip" -d "/tmp"
  sudo /tmp/aws/install --bin-dir /bin/ --update
else
  # Install AWS CLI package
  echo "Installing awscli package"
  sudo DEBIAN_FRONTEND=noninteractive apt install -y awscli
fi



################################################################################
### Userdata Scripts to Run ####################################################
################################################################################

set -x
sudo DEBIAN_FRONTEND=noninteractive apt update -y

# Define the log file
LOG_FILE="/var/log/userdata.log"

# Redirect all output (stdout and stderr) to the log file
sudo touch $LOG_FILE
sudo chmod 777 $LOG_FILE
command >> "$LOG_FILE" 2>&1

set -x


if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
  AWS_REGION="us-east-1"
  sudo -u ubuntu /snap/bin/aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
  sudo -u ubuntu /snap/bin/aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
  sudo -u ubuntu /snap/bin/aws configure set  default.region $AWS_REGION
  echo "AWS CLI configured with your credentials."
else
  echo "failed to configure aws"
fi


# install git
set -x
if ! [ -x "$(command -v git)" ]; then
    echo "Installing git..."
    set -x
    sudo DEBIAN_FRONTEND=noninteractive apt install git -y
    echo "git installed."
else
    echo "git is already installed."
fi


set -x
cd /home/ubuntu
sudo -u ubuntu /usr/bin/git clone https://github.com/N4si/DevSecOps-Project.git
cd DevSecOps-Project


if ! [ -x "$(command -v kubectl)" ]; then
    echo "Installing kubectl..."
    set -x
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/bin/
    echo "kubectl installed."
else
    echo "kubectl is already installed."
fi

# Install docker and run the app using a container
set -x 
sudo DEBIAN_FRONTEND=noninteractive apt remove docker -y
sudo DEBIAN_FRONTEND=noninteractive apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo DEBIAN_FRONTEND=noninteractive apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install docker-ce -y
sudo usermod -aG docker ubuntu
sudo systemctl start docker && sudo systemctl enable docker
sudo chmod 777 /var/run/docker.sock

set -x
sudo chown ubuntu:ubuntu /var/lib/kubelet/kubeconfig


# Install sonarqube on port 9000
set -x
sudo docker run -d --name sonar -p 9000:9000 sonarqube:lts-community

# Install trivy
set -x
# sudo DEBIAN_FRONTEND=noninteractive /usr/bin/snap install trivy
wget https://github.com/aquasecurity/trivy/releases/download/v0.50.4/trivy_0.50.4_Linux-64bit.tar.gz
tar zxvf trivy_0.50.4_Linux-64bit.tar.gz
sudo mv trivy /snap/bin/
sudo rm trivy_0.50.4_Linux-64bit.tar.gz




# Installion of Prometheus
set -x
sudo useradd --system --no-create-home --shell /bin/false prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.50.0/prometheus-2.50.0.linux-amd64.tar.gz
tar -xvf prometheus-2.50.0.linux-amd64.tar.gz
cd prometheus-2.50.0.linux-amd64/
sudo mkdir -p /data /etc/prometheus
sudo mv prometheus promtool /usr/local/bin/
sudo mv consoles/ console_libraries/ /etc/prometheus/
sudo mv prometheus.yml /etc/prometheus/prometheus.yml
sudo chown -R prometheus:prometheus /etc/prometheus/ /data/
sudo rm /home/ubuntu/DevSecOps-Project/prometheus-2.50.0.linux-amd64.tar.gz

# Prometheus service unit definition
set -x
sudo mkdir -p /etc/systemd/system
sudo touch /etc/systemd/system/prometheus.service
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service > /dev/null
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/prometheus \\
    --config.file=/etc/prometheus/prometheus.yml \\
    --storage.tsdb.path=/data \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries \\
    --web.listen-address=0.0.0.0:9090 \\
    --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to pick up the changes
set -x
sudo systemctl daemon-reload

# Enable and start the Prometheus service
sudo systemctl enable prometheus && sudo systemctl start prometheus


# sudo -u ubuntu /usr/bin/kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}, "metadata": {"annotations": {"service.beta.kubernetes.io/aws-load-balancer-type": "alb"}}}'


# Edit Prometheus Yaml file
set -x
sudo mkdir -p /etc/prometheus
sudo touch /etc/prometheus/prometheus.yml
cat <<EOF | sudo tee /etc/prometheus/prometheus.yml > /dev/null
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'netflix'
    static_configs:
      - targets: ['localhost:30007']
  
  - job_name: 'grafana'
    static_configs:
      - targets: ['localhost:3000']
  
EOF

# Reload Prometheus 

sudo iptables -F
sudo iptables -X
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT


# sudo systemctl status prometheus
curl -v -X POST http://localhost:9090/-/reload


# Installation of Grafana
set -x
sudo apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/enterprise/release/grafana-enterprise_10.4.1_amd64.deb
sudo dpkg -i grafana-enterprise_10.4.1_amd64.deb
sudo rm grafana-enterprise_10.4.1_amd64.deb

sudo systemctl start grafana-server && sudo systemctl enable grafana-server

# Installation of Kubergrunt
wget https://github.com/gruntwork-io/kubergrunt/releases/download/v0.14.2/kubergrunt_linux_amd64
sudo mv kubergrunt_linux_amd64 kubergrunt
sudo mv kubergrunt /usr/bin/
sudo chmod -R 777 /usr/bin/kubergrunt

sudo mkdir -p /tmp/worker
sudo chmod -R 777 /tmp/worker

################################################################################
### Remove apt Update from cloud-init config ###################################
################################################################################
sudo sed -i \
  's/ - package-update-upgrade-install/# Removed so that nodes do not have version skew based on when the node was started.\n# - package-update-upgrade-install/' \
  /etc/cloud/cloud.cfg
