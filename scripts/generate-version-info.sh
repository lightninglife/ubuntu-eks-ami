# #!/bin/sh

# # generates a JSON file containing version information for the software in this AMI

# set -o errexit
# set -eu

# if [ "$#" -ne 1 ]; then
#   echo "usage: $0 OUTPUT_FILE"
#   exit 1
# fi

# OUTPUT_FILE="$1"

# # packages
# sudo rpm --query --all --queryformat '\{"%{NAME}": "%{VERSION}-%{RELEASE}"\}\n' | jq --slurp --sort-keys 'add | {packages:(.)}' > "$OUTPUT_FILE"

# # binaries
# KUBELET_VERSION=$(kubelet --version | awk '{print $2}')
# if [ "$?" != 0 ]; then
#   echo "unable to get kubelet version"
#   exit 1
# fi
# echo $(jq ".binaries.kubelet = \"$KUBELET_VERSION\"" $OUTPUT_FILE) > $OUTPUT_FILE

# CLI_VERSION=$(aws --version | awk '{print $1}' | cut -d '/' -f 2)
# if [ "$?" != 0 ]; then
#   echo "unable to get aws cli version"
#   exit 1
# fi
# echo $(jq ".binaries.awscli = \"$CLI_VERSION\"" $OUTPUT_FILE) > $OUTPUT_FILE

# # cached images
# if systemctl is-active --quiet containerd; then
#   echo $(jq ".images = [ $(sudo ctr -n k8s.io image ls -q | cut -d'/' -f2- | sort | uniq | grep -v 'sha256' | xargs -r printf "\"%s\"," | sed 's/,$//') ]" $OUTPUT_FILE) > $OUTPUT_FILE
# elif [ "${CACHE_CONTAINER_IMAGES}" = "true" ]; then
#   echo "containerd must be active to generate version info for cached images"
#   exit 1
# fi


#!/bin/bash

# Generates a JSON file containing version information for the software in this AMI

set -o errexit
set -o nounset

if [ "$#" -ne 1 ]; then
  echo "usage: $0 OUTPUT_FILE"
  exit 1
fi

OUTPUT_FILE="$1"
sudo touch "$1"
sudo chmod 777 "$1"
# Packages
# dpkg-query -W -f='{"${Package}": "${Version}\n"}' | jq --slurp --sort-keys 'add | {packages: .}' > "$OUTPUT_FILE"
sudo cat "$OUTPUT_FILE"
dpkg-query -W -f='{"Package": "${Package}", "Version": "${Version}"}\n' | jq -s '{packages: .}' > "$OUTPUT_FILE"
# dpkg-query -W -f='{"Package": "${Package}", "Version": "${Version}"}\n' | jq -nR '[inputs | {(.Package): .Version}] | add' > "$OUTPUT_FILE"
# dpkg-query -W -f='{"Package": "${Package}", "Version": "${Version}"}\n' | jq -R 'split("\n") | map(split(": ")) | map({(.[0]): .[1]}) | add' > "$OUTPUT_FILE"
# dpkg-query -W -f='{"Package": "${Package}", "Version": "${Version}"}\n' | jq -R 'split("\n") | select(length > 0) | map(split(": ")) | map({key: .[0], value: .[1]}) | from_entries' > "$OUTPUT_FILE"
# dpkg-query --query --all --queryformat '\{"%{NAME}": "%{VERSION}-%{RELEASE}"\}\n' | jq --slurp --sort-keys 'add | {packages:(.)}' > "$OUTPUT_FILE"
# dpkg-query -W -f='{"Package": "${Package}", "Version": "${Version}"}\n' | jq -nR '[inputs | capture("(?<key>[^:]+): (?<value>.+)") | {(.key): .value}] | add' > "$OUTPUT_FILE"






# # Binaries
# KUBELET_VERSION=$(kubelet --version | awk '{print $2}' || echo "unable to get kubelet version")
# echo '{"binaries": {"kubelet": "'"$KUBELET_VERSION"'"}}' | jq --argjson input "$(cat "$OUTPUT_FILE")" '.binaries.awscli = input.binaries.awscli' > "$OUTPUT_FILE"

# CLI_VERSION=$(aws --version 2>&1 | awk '{print $1}' | cut -d '/' -f 2 || echo "unable to get aws cli version")
# echo "$(jq '.binaries.awscli = "'"$CLI_VERSION"'"' "$OUTPUT_FILE")" > "$OUTPUT_FILE"

# # Cached images
# if systemctl is-active --quiet containerd; then
#   IMAGES=$(sudo ctr -n k8s.io image ls -q | cut -d'/' -f2- | sort | uniq | grep -v 'sha256' || echo "")
#   IMAGES_ARRAY=$(echo "$IMAGES" | xargs -r -I '{}' printf '"%s",' '{}' | sed 's/,$//' || echo "")
#   echo '{"images": ['"$IMAGES_ARRAY"']}' | jq --argjson input "$(cat "$OUTPUT_FILE")" '.images = $input.images' > "$OUTPUT_FILE"
# elif [ "${CACHE_CONTAINER_IMAGES:-}" = "true" ]; then
#   echo "containerd must be active to generate version info for cached images"
#   exit 1
# fi


# binaries
KUBELET_VERSION=$(kubelet --version | awk '{print $2}')
if [ "$?" != 0 ]; then
  echo "unable to get kubelet version"
  exit 1
fi
echo $(jq ".binaries.kubelet = \"$KUBELET_VERSION\"" $OUTPUT_FILE) > $OUTPUT_FILE

CLI_VERSION=$(aws --version | awk '{print $1}' | cut -d '/' -f 2)
if [ "$?" != 0 ]; then
  echo "unable to get aws cli version"
  exit 1
fi
echo $(jq ".binaries.awscli = \"$CLI_VERSION\"" $OUTPUT_FILE) > $OUTPUT_FILE

# cached images
if systemctl is-active --quiet containerd; then
  echo $(jq ".images = [ $(sudo ctr -n k8s.io image ls -q | cut -d'/' -f2- | sort | uniq | grep -v 'sha256' | xargs -r printf "\"%s\"," | sed 's/,$//') ]" $OUTPUT_FILE) > $OUTPUT_FILE
elif [ "${CACHE_CONTAINER_IMAGES}" = "true" ]; then
  echo "containerd must be active to generate version info for cached images"
  exit 1
fi

sudo chmod -R 777 /tmp/worker