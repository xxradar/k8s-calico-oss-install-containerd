#!/bin/bash
NERDCTL_VERSION=$(curl -s "https://api.github.com/repos/containerd/nerdctl/releases/latest" | jq -r '.tag_name | sub("^v"; "")')

archType="amd64"
if test "$(uname -m)" = "aarch64"
then
    archType="arm64"
fi

wget -q "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-${archType}.tar.gz" -O /tmp/nerdctl.tar.gz
tar -xzf /tmp/nerdctl.tar.gz -C /tmp --strip-components 1 bin/nerdctl
chmod +x /tmp/nerdctl
sudo mv /tmp/nerdctl /usr/local/bin/
sudo nerdctl version

