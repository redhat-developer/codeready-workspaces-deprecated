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

# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/ubi8/php-73
FROM registry.access.redhat.com/ubi8/ubi:8.2-347 as builder
USER root
RUN yum install -y git wget make gcc gpgme-devel libassuan-devel  device-mapper-devel && \
    [[ "$(uname -m)" == "x86_64" ]] && export ARCH=amd64 || export ARCH="$(uname -m)" && \
    wget https://golang.org/dl/go1.14.6.linux-$ARCH.tar.gz && \
    tar xzvf go1.14.6.linux-$ARCH.tar.gz -C /usr/local && \
    ln -s /usr/local/go/bin/go  /usr/local/bin/ && \
    ln -s /usr/local/go/bin/gofmt  /usr/local/bin/
RUN export PATH=$PATH:/usr/local/bin && export GOPATH=$HOME && export CC=gcc && \
    git clone https://github.com/containers/skopeo $GOPATH/src/github.com/containers/skopeo && \
    cd $GOPATH/src/github.com/containers/skopeo && \
    make bin/skopeo && \
    cp bin/skopeo /usr/local/bin
