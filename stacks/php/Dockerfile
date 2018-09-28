FROM docker-registry.default.svc:5000/openshift/rhel-base-jdk8

ENV PHP_VERSION=7.1 \
    PHP_LS_VERSION=5.4.1 \
    PHP_VER_SHORT=71 \
    NAME=php \
    PATH=$PATH:/opt/rh/rh-php71/root/usr/bin \
    PHP_CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/php/ \
    PHP_DEFAULT_INCLUDE_PATH=/opt/rh/rh-php71/root/usr/share/pear \
    PHP_SYSCONF_PATH=/etc/opt/rh/rh-php71 \
    PHP_HTTPD_CONF_FILE=rh-php71-php.conf \
    HTTPD_CONFIGURATION_PATH=${APP_ROOT}/etc/conf.d \
    HTTPD_MAIN_CONF_PATH=/etc/httpd/conf \
    HTTPD_MAIN_CONF_D_PATH=/etc/httpd/conf.d \
    HTTPD_VAR_RUN=/var/run/httpd \
    HTTPD_DATA_PATH=/var/www \
    HTTPD_DATA_ORIG_PATH=/opt/rh/httpd24/root/var/www \
    HTTPD_VAR_PATH=/opt/rh/httpd24/root/var \
    SCL_ENABLED=rh-php71

USER root

# Install Apache httpd and PHP
RUN yum install -y yum-utils rpmdevtools && \
    prepare-yum-repositories rhel-server-rhscl-7-rpms && \
    INSTALL_PKGS="rh-php71 rh-php71-php rh-php71-php-mysqlnd rh-php71-php-pgsql rh-php71-php-bcmath \
                  rh-php71-php-gd rh-php71-php-intl rh-php71-php-ldap rh-php71-php-mbstring rh-php71-php-pdo \
                  rh-php71-php-process rh-php71-php-soap rh-php71-php-opcache rh-php71-php-xml \
                  rh-php71-php-gmp rh-php71-php-pecl-apcu httpd24-mod_ssl" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all -y && \
    cp /opt/rh/httpd24/root/usr/sbin/httpd /usr/bin/httpd && \
    sed -i '/mod_headers.so/ a LoadFile /opt/rh/httpd24/root/usr/lib64/libnghttp2-httpd24.so.14' /opt/rh/httpd24/root/etc/httpd/conf.modules.d/00-base.conf && \
    sed -i 's/Listen 80/Listen 8080/' /opt/rh/httpd24/root/etc/httpd/conf/httpd.conf && \
    sed -i 's/Listen 443/#Listen 443/' /opt/rh/httpd24/root/etc/httpd/conf.d/ssl.conf && \
    sed -i 's/opt\/rh\/httpd24\/root\/var\/www\/html/projects/' /opt/rh/httpd24/root/etc/httpd/conf/httpd.conf && \
    chmod -R 777 /opt/rh/httpd24/root/var/run/httpd /var/log/httpd24/ /etc/pki /opt/rh/httpd24/root/etc/httpd/logs && \
    ln -s /usr/lib64/libcrypto.so.1.0.2k /usr/lib64/libcrypto.so.1.0.0 && \
    ln -s /usr/lib64/libssl.so.1.0.2k /usr/lib64/libssl.so.1.0.0 && \
    sh -c 'echo -e "; configuration for php ZendDebugger module\n; priority=90\nzend_extension=ZendDebugger.so" > /etc/opt/rh/rh-php71/php.d/zenddebugger.ini'

RUN curl http://repos.zend.com/zend-server/9.1.4/rpm_apache2.4/x86_64/zend-server-php-7.1-common-9.1.4-331.x86_64.rpm -o ~/zend.rpm && \
    rpmdev-extract -C ~ ~/zend.rpm && \
    cp ~/zend-server-php-7.1-common-9.1.4-331.x86_64/usr/local/zend/lib/debugger/php-7.1.x/ZendDebugger.so /opt/rh/rh-php71/root/usr/lib64/php/modules/ZendDebugger.so && \
    rm -rf ~/zend-server-php-7.1-common-9.1.4-331.x86_64 && \
    rm ~/zend.rpm

# # A few times zend repo was unavailable, so having .so file for ZendDebugger is a way not to depend on it
# ADD ZendDebugger_7.1.so /opt/rh/rh-php71/root/usr/lib64/php/modules/ZendDebugger.so

# install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    mkdir -p /home/jboss/.composer && \
    chown -R jboss ~/.composer && \
    # install PHP Language Server
    mkdir -p ${HOME}/che/ls-php/php-language-server && \
    cd ${HOME}/che/ls-php/php-language-server && \
    composer require jetbrains/phpstorm-stubs:dev-master && \
    composer require felixfbecker/language-server:${PHP_LS_VERSION} && \
    composer run-script --working-dir=vendor/felixfbecker/language-server parse-stubs && \
    mv  vendor/* . && \
    rm -rf vendor && \
    chgrp -R 0 ${HOME}/che/ls-php && \
    chmod -R g+rwX ${HOME}/che/ls-php

USER jboss
CMD echo "apache:x:48:48:Apache:/opt/rh/httpd24/root/usr/share/httpd:/sbin/nologin" >> /etc/passwd && \
    echo "apache:x:48:" >> /etc/group && \
    tail -f /dev/null
