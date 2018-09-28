FROM registry.access.redhat.com/jboss-eap-7/eap71-openshift:1.1-7
ENV PATH="/opt/rh/rh-maven35/root/usr/bin:${PATH:-/bin:/usr/bin}" \
    MANPATH="/opt/rh/rh-maven35/root/usr/share/man:${MANPATH}" \
    PYTHONPATH="/opt/rh/rh-maven35/root/usr/lib/python2.7/site-packages${PYTHONPATH:+:}${PYTHONPATH:-}" \
    JAVACONFDIRS="/opt/rh/rh-maven35/root/etc/java${JAVACONFDIRS:+:}${JAVACONFDIRS:-}" \
    XDG_CONFIG_DIRS="/opt/rh/rh-maven35/root/etc/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}" \
    XDG_DATA_DIRS="/opt/rh/rh-maven35/root/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
    M2_HOME="/opt/rh/rh-maven35/root/usr/share/maven"
USER root
ARG SUBSCRIPTION_USERNAME
ARG SUBSCRIPTION_PASSWORD
RUN subscription-manager register --username $SUBSCRIPTION_USERNAME --password $SUBSCRIPTION_PASSWORD --auto-attach && \
    yum-config-manager --enable rhel-server-rhscl-7-rpms rhel-7-server-optional-rpms && \
    yum install java-1.8.0-openjdk-src rh-maven35 sudo git wget -y && yum clean all && rm -rf /var/cache/yum && \
    mkdir -p $HOME/che /projects && \
    for f in "/home/jboss" "/etc/passwd" "/etc/group" "/projects"; do\
        chgrp -R 0 ${f} && \
        chmod -R g+rwX ${f}; \
    done && \
    # Generate passwd.template \
    cat /etc/passwd | \
    sed s#jboss:x.*#jboss:x:\${USER_ID}:\${GROUP_ID}::\${HOME}:/bin/bash#g \
    > /home/jboss/passwd.template && \
    # Generate group.template \
    cat /etc/group | \
    sed s#root:x:0:#root:x:0:0,\${USER_ID}:#g \
    > /home/jboss/group.template && \
    echo "jboss	ALL=(ALL)	NOPASSWD: ALL" >> /etc/sudoers && \
    curl https://raw.githubusercontent.com/sclorg/s2i-base-container/master/core/root/usr/bin/prepare-yum-repositories -o /usr/bin/prepare-yum-repositories && \
    chmod +x /usr/bin/prepare-yum-repositories
ADD entrypoint.sh ${HOME}/entrypoint.sh
USER jboss
ENTRYPOINT ["/home/jboss/entrypoint.sh"]
WORKDIR /projects
CMD tail -f /dev/null
