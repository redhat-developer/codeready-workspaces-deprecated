#!/bin/bash

# install xdebug (requires internet access, running as root in a container; cannot run in Brew)

dnf install -y diffutils findutils php-fpm php-opcache php-devel php-pear php-gd php-mysqli php-zlib php-curl ca-certificates
pecl channel-update pecl.php.net
pecl install xdebug
cat << EOF > /etc/php.ini
zend_extension=$(find /usr/lib64/php/modules -name xdebug.so)
xdebug.coverage_enable=0
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_log=/tmp/xdebug.log
xdebug.remote_autostart=true
EOF
#cat /etc/php.ini
