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

export PYTHON_LS_VERSION=0.21.5
export PYTHON_IMAGE_VERSION="registry.access.redhat.com/ubi8/python-36:1"

cd $SCRIPT_DIR
[[ -e target ]] && rm -Rf target

echo ""
echo "CodeReady Workspaces :: Stacks :: Language Servers :: Python Dependencies"
echo ""

mkdir -p target/python-ls
docker run -v $SCRIPT_DIR/target/python-ls:/python -u root $PYTHON_IMAGE_VERSION sh -c "
    pip install --upgrade pip
    pip install python-language-server[all]==${PYTHON_LS_VERSION} --prefix=/python
    chmod -R 777 /python
    "
tar -czf target/codeready-workspaces-stacks-language-servers-dependencies-python-$(uname -m).tar.gz -C target/python-ls .
