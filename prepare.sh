#!/bin/sh

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
