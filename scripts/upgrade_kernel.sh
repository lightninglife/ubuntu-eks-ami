#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ -z "$KERNEL_VERSION" ]]; then
  if vercmp "$KUBERNETES_VERSION" gteq "1.24.0"; then
    KERNEL_VERSION="6.5.0-26"
  else
    KERNEL_VERSION=5.5
  fi
  echo "kernel_version is unset. Setting to $KERNEL_VERSION based on Kubernetes version $KUBERNETES_VERSION."
fi


if [[ $KERNEL_VERSION == 4.14* ]]; then
  sudo apt-get update -y
  sudo apt-get install -y "linux-image-${KERNEL_VERSION}-generic"
else
  sudo apt-get update -y
  sudo apt-get install -y "linux-modules-${KERNEL_VERSION}-generic"
fi

sudo apt-get install -y "linux-headers-${KERNEL_VERSION}-generic" "linux-modules-extra-${KERNEL_VERSION}-generic"

# # Install the kernel and kernel headers
# sudo apt update -y 
# sudo apt install -y "linux-image-$KERNEL_VERSION-generic" "linux-headers-$KERNEL_VERSION-generic"

# enable pressure stall information
echo "psi=1" | sudo tee -a /etc/default/grub
sudo update-grub

# use the tsc clocksource by default
# https://repost.aws/knowledge-center/manage-ec2-linux-clock-source
echo "clocksource=tsc tsc=reliable" | sudo tee -a /etc/default/grub
sudo update-grub

# # Use the tsc clocksource by default
# # https://repost.aws/knowledge-center/manage-ec2-linux-clock-source
# sudo grubby \
#   --update-kernel=ALL \
#   --args="psi=1 clocksource=tsc tsc=reliable"

# sudo update-grub

# sudo apt-mark hold apt-plugin-versionlock

