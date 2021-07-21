#!/bin/bash -xe

# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)

MIDSTM_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ $MIDSTM_BRANCH == "crw-2."*"-rhel-8" ]]; then
	CRW_VERSION=${MIDSTM_BRANCH/crw-/}; CRW_VERSION=${CRW_VERSION/-rhel-8/}
else
	CRW_VERSION="nightly"
fi
# echo "Using CRW_VERSION=${CRW_VERSION} and MIDSTM_BRANCH = ${MIDSTM_BRANCH}"

export KIP_IMAGE="quay.io/crw/imagepuller-rhel8:${CRW_VERSION}"

cd "$SCRIPT_DIR" || exit 1
[[ -e target ]] && rm -Rf target

echo ""
echo "CodeReady Workspaces :: scratch images :: multi-arch sleep binary"
echo ""

mkdir -p target/sleep

PODMAN=$(command -v podman || true)
if [[ ! -x $PODMAN ]]; then
  echo "[WARNING] podman is not installed."
 PODMAN=$(command -v docker || true)
  if [[ ! -x $PODMAN ]]; then
    echo "[ERROR] docker is not installed. Aborting."; exit 1
  fi
fi

${PODMAN} run --rm -v "$SCRIPT_DIR"/target/sleep:/sleep -u root ${KIP_IMAGE} sh -c "
    cp /bin/sleep /sleep
    chmod -R 777 /sleep
    "
tar -czf "target/codeready-workspaces-sleep-$(uname -m).tar.gz" -C target/sleep sleep

${PODMAN} rmi -f ${KIP_IMAGE}
