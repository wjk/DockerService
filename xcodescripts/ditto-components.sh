#!/bin/zsh

set -e

fail () {
	echo "/usr/local/opt/$1 not found, please install using \`brew install $1\`" 1>&2
	exit 1
}

[ -d "/usr/local/opt/docker" ] || fail "docker"
[ -d "/usr/local/opt/docker-machine" ] || fail "docker-machine"
[ -d "/usr/local/opt/docker-machine-driver-xhyve" ] || fail "docker-machine-driver-xhyve"

ditto /usr/local/opt/docker ${SRCROOT}/components/docker
ditto /usr/local/opt/docker-machine ${SRCROOT}/components/docker-machine
ditto /usr/local/opt/docker-machine-driver-xhyve ${SRCROOT}/components/docker-machine-driver-xhyve
