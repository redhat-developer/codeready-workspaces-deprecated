#!/bin/bash

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

export KAMEL_VERSION="1.2.0"
export GOLANG_IMAGE_VERSION="registry.access.redhat.com/ubi8/go-toolset"

cd $SCRIPT_DIR
[[ -e target ]] && rm -Rf target

echo ""
echo "CodeReady Workspaces :: Kamel"
echo ""

mkdir -p target/kamel
docker run --rm -v $SCRIPT_DIR/target/kamel:/kamel -u root $GOLANG_IMAGE_VERSION sh -c "
    wget https://github.com/apache/camel-k/archive/${KAMEL_VERSION}.tar.gz -O /tmp/camel-k-client-${KAMEL_VERSION}-src.tar.gz
    cd /tmp
    tar xzf /tmp/camel-k-client-${KAMEL_VERSION}-src.tar.gz
    cd camel-k-${KAMEL_VERSION}
    make build-kamel
    cp  /tmp/camel-k-${KAMEL_VERSION}/kamel /kamel/kamel
    "
tar -czf target/kamel-${KAMEL_VERSION}-$(uname -m).tar.gz -C target/kamel .
