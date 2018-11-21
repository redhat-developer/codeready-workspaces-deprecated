# Copyright (c) 2018 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

# repo for a local build
#FROM registry.access.redhat.com/openshift3/apb-base:v3.10.45-6
FROM openshift3/apb-base:v3.10.45-6

ENV SUMMARY="Red Hat CodeReady Workspaces Ansible Playbook Bundle that provides the Red Hat CodeReady Workspaces (Eclipse Che Server)" \
    DESCRIPTION="Red Hat CodeReady Workspaces Ansible Playbook Bundle that provides the Red Hat CodeReady Workspaces (Eclipse Che Server)" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="server-apb"

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Red Hat CodeReady Workspaces for OpenShift - Ansible Playbook Bundle" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME" \
      name="$PRODNAME/$COMPNAME" \
      version="1.0.0.Beta1" \
      license="EPLv2" \
      maintainer="Nick Boldt <nboldt@redhat.com>" \
      io.openshift.expose-services="" \
      usage=""

USER root
# uncomment to run a local build
#RUN subscription-manager register --username username --password password --auto-attach
#RUN subscription-manager repos --enable rhel-7-server-optional-rpms \
#      --enable rhel-server-rhscl-7-rpms
RUN yum install -y python27-python-psycopg2.x86_64 && \
    yum clean all -y && \
    cp -R /opt/rh/python27/root/usr/lib64/python2.7/site-packages/* /usr/lib/python2.7/site-packages
COPY playbooks /opt/apb/actions
COPY roles /opt/ansible/roles
RUN chmod -R g=u /opt/{ansible,apb}
USER apb