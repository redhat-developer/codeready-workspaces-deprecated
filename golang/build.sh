#!/bin/bash -e

# Copyright (c) 2018-2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

export SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)

export GOLANG_IMAGE="golang:1.12"
export GOLANG_LINT_VERSION="v1.22.2"
export GOLANG_LS_OLD_DEPS="console-stamp@0.2.9 strip-ansi@5.2.0 has-ansi@4.0.0 ansi-regex@4.1.0 chalk@2.4.2 escape-string-regexp@2.0.0 ansi-styles@4.1.0 supports-color@7.0.0"
export GOLANG_LS_VERSION="0.1.7"
export NODEJS_IMAGE="node:8.16-alpine"  # find latest version: https://hub.docker.com/_/node/?tab=description
#export NODEJS_IMAGE="node:10.16-alpine"

cd $SCRIPT_DIR
[[ -e target ]] && rm -Rf target

echo ""
echo "CodeReady Workspaces :: Stacks :: Language Servers :: Golang Dependencies"
echo ""

mkdir -p target/go

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then
  echo "[WARNING] podman is not installed."
 PODMAN=$(command -v docker)
  if [[ ! -x $PODMAN ]]; then
    echo "[ERROR] docker is not installed. Aborting."; exit 1
  fi
fi

# get LS itself as npm module
${PODMAN} run --rm -v $SCRIPT_DIR/target:/node_modules ${NODEJS_IMAGE} sh -c "
    npm install --prefix /node_modules ${GOLANG_LS_OLD_DEPS} go-language-server@${GOLANG_LS_VERSION}
    chmod -R 777 /node_modules
    "
# go get LS go deps
${PODMAN} run --rm -v $SCRIPT_DIR/target/go:/go ${GOLANG_IMAGE} sh -c "
    go get -v github.com/stamblerre/gocode;
    go get -v github.com/uudashr/gopkgs/cmd/gopkgs;
    go get -v github.com/ramya-rao-a/go-outline;
    go get -v github.com/acroca/go-symbols;
    go get -v golang.org/x/tools/cmd/guru;
    go get -v golang.org/x/tools/cmd/gorename;
    go get -v github.com/fatih/gomodifytags;
    go get -v github.com/haya14busa/goplay/cmd/goplay;
    go get -v github.com/josharian/impl;
    go get -v golang.org/x/tools/cmd/gotype;
    go get -v github.com/rogpeppe/godef;
    go get -v golang.org/x/tools/cmd/godoc;
    go get -v github.com/zmb3/gogetdoc;
    go get -v golang.org/x/tools/cmd/goimports;
    go get -v sourcegraph.com/sqs/goreturns;
    go get -v golang.org/x/lint/golint;
    go get -v github.com/cweill/gotests/...;
    go get -v honnef.co/go/tools/...;
    go get -v github.com/sourcegraph/go-langserver;
    go get -v github.com/go-delve/delve/cmd/dlv;
    go get -v github.com/davidrjenni/reftools/cmd/fillstruct;
    go get -v golang.org/x/tools/gopls;
    go build -o /go/bin/gocode-gomod github.com/stamblerre/gocode;
    wget -O- -nv https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s ${GOLANG_LINT_VERSION}
    chmod -R 777 /go
    "
tar -czf target/codeready-workspaces-stacks-language-servers-dependencies-golang-$(uname -m).tar.gz -C target go node_modules

${PODMAN} rmi -f ${NODEJS_IMAGE} ${GOLANG_IMAGE}