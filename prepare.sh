#!/bin/sh

cat << EOF >>/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

apk add --update-cache  \
 bash  \
 wget  \
 git  \
 unzip  \
 tar  \
 xz  \
 coreutils  \
 binutils  \
 libressl  \
 ca-certificates  \
 ostree

. ./functions.sh
. ./glib.sh
