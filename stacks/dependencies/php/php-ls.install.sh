#!/bin/bash

#!# install php-ls (requires internet access, running as root in a container; cannot run in Brew)

mkdir -p /php
cd /php
chmod -R 777 /php
wget https://getcomposer.org/installer -O /tmp/composer-installer.php
php /tmp/composer-installer.php --filename=composer --install-dir=/usr/local/bin
