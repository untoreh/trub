#!/bin/sh

source functions.sh

repo="untoreh/trub"
os="trub"
base_url="https://partner-images.canonical.com/core/xenial/current/ubuntu-xenial-core-cloudimg-amd64-root.tar.gz"
rootfs="/srv/tree"

## get release tag
newV=`last_release $repo`

printc "$newV is the new version"

## tree init
prepare_rootfs $rootfs
cd $rootfs

## fetch cloud image
wget $base_url -qO artifact
tar xf artifact
rm artifact

# add additional packages

## save the new version number
echo -n "$newV" >etc/${os}

##
wrap_rootfs $rootfs
cd -
