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

# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/rhel8/go-toolset
FROM registry.access.redhat.com/ubi8/go-toolset as builder
USER root
ENV KAMEL_VERSION="1.0.0-RC2"

#COPY camel-k-client-${KAMEL_VERSION}-src.tar.gz /tmp/
RUN wget https://github.com/apache/camel-k/archive/${KAMEL_VERSION}.tar.gz -O /tmp/camel-k-client-${KAMEL_VERSION}-src.tar.gz

RUN cd /tmp && tar xzvf /tmp/camel-k-client-${KAMEL_VERSION}-src.tar.gz && \
   cd camel-k-${KAMEL_VERSION} && \
   make build-kamel
