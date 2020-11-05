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

export NODEJS_IMAGE="node:10.15-alpine"  # find latest version: https://hub.docker.com/_/node/?tab=description
export NODEMON_VERSION=1.19.3  # find latest version: https://www.npmjs.com/package/nodemon
export TYPERSCRIPT_VERSION=3.4.5  # find latest version: https://www.npmjs.com/package/typescript
export TYPESCRIPT_LS_VERSION=0.3.7  # find latest version: https://www.npmjs.com/package/typescript-language-server

cd $SCRIPT_DIR
[[ -e target ]] && rm -Rf target

echo ""
echo "CodeReady Workspaces :: Stacks :: Language Servers :: Node 10 Dependencies"
echo ""

mkdir -p target/nodejs-ls

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then
  echo "[WARNING] podman is not installed."
 PODMAN=$(command -v docker)
  if [[ ! -x $PODMAN ]]; then
    echo "[ERROR] docker is not installed. Aborting."; exit 1
  fi
fi

${PODMAN} run --rm -v $SCRIPT_DIR/target/nodejs-ls:/node_modules -u root ${NODEJS_IMAGE} sh -c "
    npm install --prefix /node_modules nodemon@${NODEMON_VERSION} typescript@${TYPERSCRIPT_VERSION} typescript-language-server@${TYPESCRIPT_LS_VERSION}
    chmod -R 777 /node_modules
    "
tar -czf target/codeready-workspaces-stacks-language-servers-dependencies-node10-$(uname -m).tar.gz -C target/nodejs-ls .

${PODMAN} rmi -f ${NODEJS_IMAGE}
