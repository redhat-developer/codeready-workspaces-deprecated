#!/bin/bash -x

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

export LOMBOK_VERSION="1.18.18"

mkdir -p target && cd target
curl -sSLo lombok.jar https://projectlombok.org/downloads/lombok-${LOMBOK_VERSION}.jar

# now fetch target/lombok.jar in get-sources-jenkins.sh for use in Brew builds

# Or... move this downstream entirely into get-sources-jenkins for the 4 java based plugin sidecars, eg., 
# https://github.com/redhat-developer/codeready-workspaces-images/blob/crw-2-rhel-8/codeready-workspaces-plugin-java11/get-sources-jenkins.sh#L56-L57
