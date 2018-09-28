FROM docker-registry.default.svc:5000/openshift/rhel-base-jdk8

ENV PYTHON_LS_VERSION=0.18.0 \
    PYTHON_VERSION=3.6 \
    PATH=$HOME/.local/bin/:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    PIP_NO_CACHE_DIR=off \
    PATH=/opt/rh/rh-python36/root/usr/bin${PATH:+:${PATH}} \
    LD_LIBRARY_PATH=/opt/rh/rh-python36/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} \
    MANPATH=/opt/rh/rh-python36/root/usr/share/man:$MANPATH \
    PKG_CONFIG_PATH=/opt/rh/rh-python36/root/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}} \
    XDG_DATA_DIRS="/opt/rh/rh-python36/root/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

RUN sudo yum install -y yum-utils && \
    sudo prepare-yum-repositories rhel-server-rhscl-7-rpms && \
    INSTALL_PKGS="rh-python36 rh-python36-python-devel rh-python36-python-setuptools rh-python36-python-pip \
	                nss_wrapper httpd24 httpd24-httpd-devel httpd24-mod_ssl httpd24-mod_auth_kerb httpd24-mod_ldap \
                  httpd24-mod_session atlas-devel gcc-gfortran libffi-devel libtool-ltdl enchant" && \
    sudo yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    sudo rpm -V $INSTALL_PKGS && \
    # Remove redhat-logos (httpd dependency) to keep image size smaller.
    sudo rpm -e --nodeps redhat-logos && \
    sudo yum clean all -y && \
    sudo chmod -R 777 /opt/rh/rh-python36/root/usr && \
    pip install --upgrade pip && \
    pip install python-language-server[all]==${PYTHON_LS_VERSION} && \
    mkdir ${HOME}/.cache && \
    sudo chgrp -R 0 ${HOME}/.cache && \
    sudo chmod -R g+rwX ${HOME}/.cache
