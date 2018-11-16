# Copyright (c) 2018 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

FROM registry.access.redhat.com/openshift3/apb-base:v3.10.45-6
# FROM openshift3/apb-base:v3.10.45-6

ENV SUMMARY="Red Hat CodeReady Workspaces Ansible Playbook Bundle that provides the Red Hat CodeReady Workspaces (Eclipse Che Server)" \
    DESCRIPTION="Red Hat CodeReady Workspaces Ansible Playbook Bundle that provides the Red Hat CodeReady Workspaces (Eclipse Che Server)" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="apb"

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Red Hat CodeReady Workspaces for OpenShift - Ansible Playbook Bundle" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME" \
      name="$PRODNAME/$COMPNAME" \
      version="1.0.0.GA" \
      license="EPLv2" \
      maintainer="Nick Boldt <nboldt@redhat.com>" \
      io.openshift.expose-services="" \
      usage=""

COPY playbooks /opt/apb/actions
COPY roles /opt/ansible/roles
RUN chmod -R g=u /opt/{ansible,apb} && \
    find /opt/ansible/roles/keycloak-apb -type f | xargs sed -i "s/'persistent'/'prod'/g" && \
    find /opt/ansible/roles/keycloak-apb -type f | xargs sed -i "s/'ephemeral'/'dev'/g"
