# #!/bin/bash
# # https://aws.amazon.com/blogs/publicsector/enabling-fips-mode-amazon-linux-2/
# if [[ "$ENABLE_FIPS" == "true" ]]; then
#   # install and enable fips modules
#   sudo yum install -y dracut-fips openssl
#   sudo dracut -f

#   # enable fips in the boot command
#   sudo /sbin/grubby --update-kernel=ALL --args="fips=1"
# fi


#!/bin/bash
# https://aws.amazon.com/blogs/publicsector/enabling-fips-mode-amazon-linux-2/
if [[ "$ENABLE_FIPS" == "true" ]]; then
  # Install and enable fips modules
  sudo apt-get update
  sudo apt-get install -y dracut-fips openssl

  # Rebuild the initramfs to include fips modules
  sudo update-initramfs -u

  # Enable FIPS mode
  sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&fips=1 /' /etc/default/grub
  sudo update-grub
fi
