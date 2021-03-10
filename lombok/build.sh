#!/bin/bash -x

# Copyright (c) 2018-2021 Red Hat, Inc.
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

export LOMBOK_VERSION="1.18.18"
export IMAGE="registry.access.redhat.com/ubi8"

cd $SCRIPT_DIR
[[ -e target ]] && rm -Rf target

echo ""
echo "CodeReady Workspaces :: Lombok"
echo ""

mkdir -p target/lombok

PODMAN=$(command -v podman || true)
if [[ ! -x $PODMAN ]]; then
  echo "[WARNING] podman is not installed."
 PODMAN=$(command -v docker || true)
  if [[ ! -x $PODMAN ]]; then
    echo "[ERROR] docker is not installed. Aborting."; exit 1
  fi
fi

${PODMAN} run --rm -v $SCRIPT_DIR/target/lombok:/lombok ${IMAGE} sh -c "
    cd /tmp
    curl -sSL -O https://projectlombok.org/downloads/lombok-${LOMBOK_VERSION}.jar
    cp lombok-${LOMBOK_VERSION}.jar /lombok
    "
 
tar -czf target/lombok-${LOMBOK_VERSION}-$(uname -m).tar.gz -C target/lombok .

${PODMAN} rmi -f ${IMAGE}

