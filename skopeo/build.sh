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

export SKOPEO_IMAGE="registry.redhat.io/rhel8/skopeo" # 8.3-13

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

# to use the latest nightly, uncomment the next line and build locally
# ${PODMAN} build -t ${SKOPEO_IMAGE} . 

# pull skopeo binary from the container (either built above, or fetched from reg.rh.io)
${PODMAN} run --rm -v $SCRIPT_DIR/target:/skopeo ${SKOPEO_IMAGE} sh -c "cp /usr/bin/skopeo /skopeo"
tar -czf target/skopeo-$(uname -m).tar.gz -C target skopeo

${PODMAN} rmi -f ${SKOPEO_IMAGE}
