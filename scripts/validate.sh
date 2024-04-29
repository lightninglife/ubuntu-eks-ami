#!/usr/bin/env bash

set -o nounset
set -o errexit
set -eu

validate_file_nonexists() {
  local file_blob=$1
  for f in $file_blob; do
    if [ -e "$f" ]; then
      echo "$f shouldn't exists"
      exit 1
    fi
  done
}

validate_file_nonexists '/etc/hostname'
# validate_file_nonexists '/etc/resolv.conf'
validate_file_nonexists '/etc/ssh/ssh_host*'
validate_file_nonexists '/home/ec2-user/.ssh/authorized_keys'
validate_file_nonexists '/root/.ssh/authorized_keys'
validate_file_nonexists '/var/lib/cloud/data'
validate_file_nonexists '/var/lib/cloud/instance'
validate_file_nonexists '/var/lib/cloud/instances'
validate_file_nonexists '/var/lib/cloud/sem'
validate_file_nonexists '/var/lib/dhclient/*'
validate_file_nonexists '/var/lib/dhcp/dhclient.*'
validate_file_nonexists '/var/lib/yum/history'
validate_file_nonexists '/var/log/cloud-init-output.log'
validate_file_nonexists '/var/log/cloud-init.log'
validate_file_nonexists '/var/log/secure'
validate_file_nonexists '/var/log/wtmp'

actual_kernel=$(uname -r)
echo "Verifying that kernel version $actual_kernel matches $KERNEL_VERSION..."

if [[ $actual_kernel == $KERNEL_VERSION* ]]; then
  echo "Kernel matches expected version!"
else
  echo "Kernel does not match expected version!"
  exit 1
fi

# function versionlock-entries() {
#   # the format of this output is EPOCH:NAME-VERSION-RELEASE.ARCH
#   # more info in yum-versionlock(1)
#   # rpm doesn't accept EPOCH when querying the db, so remove it
#   yum versionlock list --quiet | cut -d ':' -f2
# }

function versionlock_entries() {
  # List installed packages and their versions
  dpkg-query -W -f='${Package}:${Version}\n' | cut -d ':' -f 1,2
}


# function versionlock-packages() {
#   versionlock-entries | xargs -I '{}' rpm --query '{}' --queryformat '%{NAME}\n'
# }

function versionlock_packages() {
  versionlock_entries | awk -F ':' '{print $1}'
}


# function verify-versionlocks() {
#   for ENTRY in $(versionlock-entries); do
#     if ! rpm --query "$ENTRY" &> /dev/null; then
#       echo "There is no package matching the versionlock entry: '$ENTRY'"
#       exit 1
#     fi
#   done

#   LOCKED_PACKAGES=$(versionlock-packages | wc -l)
#   UNIQUE_LOCKED_PACKAGES=$(versionlock-packages | sort -u | wc -l)
#   if [ $LOCKED_PACKAGES -ne $UNIQUE_LOCKED_PACKAGES ]; then
#     echo "Package(s) have multiple version locks!"
#     versionlock-entries
#   fi

#   echo "Package versionlocks are correct!"
# }

# # run verify-versionlocks on al2 only, as it is not needed on al2023
# if ! cat /etc/*release | grep "al2023" > /dev/null 2>&1; then
#   echo "Verifying that the package versionlocks are correct..."
#   verify-versionlocks
# fi

# REQUIRED_COMMANDS=(unpigz)

# for ENTRY in "${REQUIRED_COMMANDS[@]}"; do
#   if ! command -v "$ENTRY" > /dev/null; then
#     echo "Required command does not exist: '$ENTRY'"
#     exit 1
#   fi
# done

# echo "Required commands were found: ${REQUIRED_COMMANDS[*]}"

# REQUIRED_FREE_MEBIBYTES=1024
# TOTAL_MEBIBYTES=$(df -m / | tail -n1 | awk '{print $2}')
# FREE_MEBIBYTES=$(df -m / | tail -n1 | awk '{print $4}')
# echo "Disk space in mebibytes (required/free/total): ${REQUIRED_FREE_MEBIBYTES}/${FREE_MEBIBYTES}/${TOTAL_MEBIBYTES}"
# if [ ${FREE_MEBIBYTES} -lt ${REQUIRED_FREE_MEBIBYTES} ]; then
#   echo "Disk space requirements not met!"
#   exit 1
# else
#   echo "Disk space requirements were met."
# fi

# Function to verify version locks
function verify_versionlocks() {
  for ENTRY in $(versionlock_entries); do
    if ! dpkg -s $(echo $ENTRY | cut -d ":" -f1) &> /dev/null; then
      echo "There is no package matching the versionlock entry: '$ENTRY'"
      exit 1
    fi
  done

  LOCKED_PACKAGES=$(versionlock_packages | wc -l)
  UNIQUE_LOCKED_PACKAGES=$(versionlock_packages | sort -u | wc -l)
  if [ $LOCKED_PACKAGES -ne $UNIQUE_LOCKED_PACKAGES ]; then
    echo "Package(s) have multiple version locks!"
    versionlock_entries
    exit 1
  fi

  echo "Package version locks are correct!"
}

# Run verify_versionlocks on Ubuntu Server
echo "Verifying that the package version locks are correct..."
verify_versionlocks

# Check for required commands
REQUIRED_COMMANDS=("unpigz")

for ENTRY in "${REQUIRED_COMMANDS[@]}"; do
  if ! command -v "$ENTRY" &> /dev/null; then
    echo "Required command does not exist: '$ENTRY'"
    exit 1
  fi
done

echo "Required commands were found: ${REQUIRED_COMMANDS[*]}"

# Check disk space
REQUIRED_FREE_MEBIBYTES=1024
FREE_MEBIBYTES=$(df -m / | tail -n1 | awk '{print $4}')
TOTAL_MEBIBYTES=$(df -m / | tail -n1 | awk '{print $2}')
echo "Disk space in mebibytes (required/free/total): ${REQUIRED_FREE_MEBIBYTES}/${FREE_MEBIBYTES}/${TOTAL_MEBIBYTES}"
if [ ${FREE_MEBIBYTES} -lt ${REQUIRED_FREE_MEBIBYTES} ]; then
  echo "Disk space requirements not met!"
  exit 1
else
  echo "Disk space requirements were met."
fi