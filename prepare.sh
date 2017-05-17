#!/bin/sh

cat <<EOF > /etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/latest-stable/main
http://dl-cdn.alpinelinux.org/alpine/latest-stable/community
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

apk add --update-cache \
    bash \
	wget \
	git \
	unzip \
	xz \
	coreutils \
	binutils \
	ca-certificates \
	ostree

source ./functions.sh
source ./glib.sh
