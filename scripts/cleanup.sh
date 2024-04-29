#!/usr/bin/env bash

# Clean up yum caches to reduce the image size
# sudo yum clean all
# sudo rm -rf /var/cache/yum

# # Clean up files to reduce confusion during debug
# sudo rm -rf \
#   /etc/hostname \
#   /etc/machine-id \
#   /etc/resolv.conf \
#   /etc/ssh/ssh_host* \
#   /home/ec2-user/.ssh/authorized_keys \
#   /root/.ssh/authorized_keys \
#   /var/lib/cloud/data \
#   /var/lib/cloud/instance \
#   /var/lib/cloud/instances \
#   /var/lib/cloud/sem \
#   /var/lib/dhclient/* \
#   /var/lib/dhcp/dhclient.* \
#   /var/lib/yum/history \
#   /var/log/cloud-init-output.log \
#   /var/log/cloud-init.log \
#   /var/log/secure \
#   /var/log/wtmp \
#   /var/log/messages \
#   /var/log/audit/*

# sudo touch /etc/machine-id


# #!/usr/bin/env bash

# # Clean up APT caches to reduce the image size
# sudo apt-get clean
# sudo rm -rf /var/lib/apt/lists/*

# Clean up files to reduce confusion during debug
sudo rm -rf \
  /etc/hostname \
  /etc/machine-id \
  /etc/ssh/ssh_host* \
  /home/ubuntu/.ssh/authorized_keys \
  /root/.ssh/authorized_keys \
  /var/lib/cloud/data \
  /var/lib/cloud/instances \
  /var/lib/cloud/sem \
  /var/lib/dhcp/* \
  /var/lib/cloud/instance \
  /var/lib/dhclient/* \
  /var/lib/dhcp/dhclient.* \
  /var/log/cloud-init-output.log \
  /var/log/cloud-init.log \
  /var/log/auth.log \
  /var/log/boot.log \
  /var/log/dpkg.log \
  /var/log/syslog \
  /var/log/messages \
  /var/log/secure \
  /var/log/wtmp

sudo touch /etc/machine-id
