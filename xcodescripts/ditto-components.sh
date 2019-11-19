#!/bin/zsh

set -e

fail () {
	echo "/usr/local/opt/$1 not found, please install using \`brew install $1\`" 1>&2
	exit 1
}

[ -d "/usr/local/opt/docker" ] || fail "docker"
[ -d "/usr/local/opt/docker-machine" ] || fail "docker-machine"

ditto "/usr/local/opt/docker/bin/docker" "${SRCROOT}/components"
ditto "/usr/local/opt/docker-machine/bin/docker-machine" "${SRCROOT}/components"

mkdir -p $DERIVED_FILE_DIR
touch "${DERIVED_FILE_DIR}/ditto-components.stamp"
