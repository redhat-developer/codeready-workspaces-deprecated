#!/bin/bash

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

export SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)

export PHP_LS_VERSION=5.4.6
export PHP_LS_IMAGE="php-ls:tmp"
export PHP_XDEBUG_IMAGE="php-xdebug:tmp"

cd $SCRIPT_DIR
[[ -e target ]] && rm -Rf target

echo ""
echo "CodeReady Workspaces :: Stacks :: Language Servers :: PHP Dependencies"
echo ""

mkdir -p target/php-ls
docker build . -t $PHP_LS_IMAGE -f php-ls.Dockerfile
docker run --rm -v $SCRIPT_DIR/target/php-ls:/php $PHP_LS_IMAGE sh -c "
    cd /php
    /usr/local/bin/composer require jetbrains/phpstorm-stubs:dev-master
    /usr/local/bin/composer require felixfbecker/language-server:${PHP_LS_VERSION}
    /usr/local/bin/composer run-script --working-dir=vendor/felixfbecker/language-server parse-stubs
    mv vendor/* .
    rm -rf vendor
    cp /usr/local/bin/composer /php/composer
    chmod -R 777 /php/*
    "
tar -czf target/codeready-workspaces-stacks-language-servers-dependencies-php-$(uname -m).tar.gz -C target/php-ls .

mkdir -p target/php-xdebug
docker build . -t $PHP_XDEBUG_IMAGE -f xdebug.Dockerfile
docker run -v $SCRIPT_DIR/target/php-xdebug:/xd $PHP_XDEBUG_IMAGE sh -c "
    mkdir -p /xd/etc /xd/usr/share/doc/pecl/xdebug /xd/usr/lib64/php/modules/
    cp /etc/php.ini /xd/etc/php.ini
    cp -r /usr/share/doc/pecl/xdebug/* /xd/usr/share/doc/pecl/xdebug/
    cp /usr/lib64/php/modules/xdebug.so /xd/usr/lib64/php/modules/xdebug.so
    chmod -R 777 /xd
    "
tar -czf target/codeready-workspaces-stacks-language-servers-dependencies-php-xdebug-$(uname -m).tar.gz -C target/php-xdebug .

docker rmi -f $PHP_LS_IMAGE $PHP_BUILDER_IMAGE
