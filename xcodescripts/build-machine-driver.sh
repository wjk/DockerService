#!/bin/zsh

set -e -x

export GOPATH=${DERIVED_FILE_DIR}/go
mkdir -p $GOPATH

cd ${SRCROOT}/components/docker-machine-driver-xhyve
go get github.com/zchee/docker-machine-driver-xhyve
cd $GOPATH/src/github.com/zchee/docker-machine-driver-xhyve

git checkout -- . # so the patches don't complain that they were already applied
patch -p1 < ${SRCROOT}/files/xhyve-patches/fix-makefile.patch
patch -p1 < ${SRCROOT}/files/xhyve-patches/remove-sudo-check.patch
make build

mkdir -p ${SRCROOT}/components/doker-machine-driver-xhyve
cp bin/docker-machine-driver-xhyve ${SRCROOT}/components/docker-machine-driver-xhyve
