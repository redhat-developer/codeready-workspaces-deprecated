#!/bin/bash

stacks="golang kamel node10 php python"

if [ "$1" == "clean" ] ; then
  for b in $stacks ; do
    rm -Rf $b/target
  done
  exit 0
fi

for b in $stacks ; do
  $b/build.sh
done
