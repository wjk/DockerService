#!/bin/zsh

set -e

MY_DIR=$(cd `dirname $0` && pwd)
mkdir -p $MY_DIR/build && cd $MY_DIR/build

echo '*** Step 0: Check Prerequisites'

command which -s brew || {
    echo "Error: Homebrew not found" 1>&2
    exit 1
}

echo '*** Step 1: Install components from Homebrew'

brew install docker docker-machine docker-machine-driver-xhyve

echo '*** Step 2: Assemble DockerService.bundle'

mkdir -p bundle-prefix && cd bundle-prefix
mkdir -p DockerService.bundle/Contents/Prefix
mkdir -p DockerService.bundle/Contents/Resources/Licenses
ditto /usr/local/opt/docker DockerService.bundle/Contents/Prefix
ditto /usr/local/opt/docker-machine DockerService.bundle/Contents/Prefix
ditto /usr/local/opt/docker-machine-driver-xhyve DockerService.bundle/Contents/Prefix

# Remove files shared between multiple Brew packages
rm -f DockerService.bundle/Contents/Prefix/CHANGELOG.md
rm -f DockerService.bundle/Contents/Prefix/INSTALL_RECEIPT.json
rm -f DockerService.bundle/Contents/Prefix/LICENSE
rm -f DockerService.bundle/Contents/Prefix/README.md
rm -f DockerService.bundle/Contents/Prefix/homebrew.mxcl.docker-machine.plist
rm -rf DockerService.bundle/Contents/Prefix/.brew

curl -sL --fail -o DockerService.bundle/Contents/Resources/Licenses/docker.txt \
    https://github.com/docker/docker-ce/raw/master/components/cli/LICENSE
ditto /usr/local/opt/docker-machine/LICENSE DockerService.bundle/Contents/Resources/Licenses/docker-machine.txt
ditto /usr/local/opt/docker-machine-driver-xhyve/LICENSE DockerService.bundle/Contents/Resources/Licenses/docker-machine-driver-xhyve.txt

echo '*** Done!'
