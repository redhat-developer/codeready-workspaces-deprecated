FROM docker-registry.default.svc:5000/openshift/rhel-base-jdk8
ENV NODEJS_VERSION=8 \
    TYPESCRIPT_LS_VERSION=0.1.12 \
    TYPERSCRIPT_VERSION=2.8.4 \
    NPM_RUN=start \
    NAME=nodejs \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:/opt/rh/rh-nodejs8/root/usr/bin:$PATH \
    LD_LIBRARY_PATH=/opt/rh/rh-nodejs8/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} \
    PYTHONPATH=/opt/rh/rh-nodejs8/root/usr/lib/python2.7/site-packages${PYTHONPATH:+:${PYTHONPATH}} \
    MANPATH=/opt/rh/rh-nodejs8/root/usr/share/man:$MANPATH
USER root
RUN yum install -y yum-utils && \
    prepare-yum-repositories rhel-server-rhscl-7-rpms && \
    yum remove -y rh-nodejs6\* && \
    INSTALL_PKGS="rh-nodejs8 rh-nodejs8-npm rh-nodejs8-nodejs-nodemon nss_wrapper" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    npm install -g typescript@${TYPERSCRIPT_VERSION} typescript-language-server@${TYPESCRIPT_LS_VERSION} && \
    yum clean all -y && \
    for f in "${HOME}/.config" "${HOME}/.npm"; do\
        chgrp -R 0 ${f} && \
        chmod -R g+rwX ${f}; \
    done
USER jboss
