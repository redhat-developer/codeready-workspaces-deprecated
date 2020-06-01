#!/bin/bash

export CRW_VERSION="2.2.0.GA"

if [ "$1" == "clean" ] ; then
  for b in $stacks ; do
    rm -Rf $b/target
  done
  exit 0
fi

stacks="golang  Jenkinsfile  kamel  LICENSE  node10  php  python"
for b in $stacks ; do
  $b/build.sh
done
