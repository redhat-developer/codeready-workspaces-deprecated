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

export SKOPEO_IMAGE="skopeo:tmp"

cd $SCRIPT_DIR
[[ -e target ]] && rm -Rf target

echo ""
echo "CodeReady Workspaces :: skopeo"
echo ""

mkdir -p target

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then
  echo "[WARNING] podman is not installed."
 PODMAN=$(command -v docker)
  if [[ ! -x $PODMAN ]]; then
    echo "[ERROR] docker is not installed. Aborting."; exit 1
  fi
fi

${PODMAN} build -t ${SKOPEO_IMAGE} .
${PODMAN} run --rm -v $SCRIPT_DIR/target:/skopeo ${SKOPEO_IMAGE} sh -c "
    cp /usr/local/bin/skopeo /skopeo
    "
tar -czf target/skopeo-$(uname -m).tar.gz -C target skopeo

${PODMAN} rmi -f ${SKOPEO_IMAGE}
