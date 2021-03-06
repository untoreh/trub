#!/bin/bash

shopt -s expand_aliases &>/dev/null
cn="\033[1;32;40m"
cf="\033[0m"
printc() {
	echo -e "${cn}$@${cf}"
}

git_versions() {
	git ls-remote -t git://github.com/"$1".git | awk '{print $2}' | cut -d '/' -f 3 | grep -v "\-rc" | cut -d '^' -f 1 | sed 's/^v//'
}

pine_version() {
	git_versions untoreh/pine | sort -bt- -k1nr -k2nr | head -1
}

last_version() {
	git_versions $1 | sort -bt. -k1nr -k2nr -k3r -k4r -k5r | head -1
}

## $1 repo
last_release() {
	wget -qO- https://api.github.com/repos/${1}/releases/latest \
		| awk '/tag_name/ { print $2 }' | head -1 | sed -r 's/",?//g'
}

## get a valid next tag for the current git repo format: YY.MM-X
md(){
    giturl=$(git remote show origin | grep -i fetch | awk '{print $3}')
    [[ -z "`echo $giturl | grep github`" ]] && echo "'md' tagging method currently works only with github repos, terminating." && exit 1
    prevV=$(git ls-remote -t $giturl | awk '{print $2}' | cut -d '/' -f 3 | grep -v "\-rc" | cut -d '^' -f 1 | sed 's/^v//' )
    if [[ -n "$tag_prefix" ]]; then
        prevV=$(echo "$prevV" | grep $tag_prefix | sed 's/'$tag_prefix'-//' | sort -bt- -k1nr -k2nr | head -1)
    else
        echo "no \$tag_prefix specified, using to prefix." 1>&2
        prevV=$(echo "$prevV" | sort -bt- -k1nr -k2nr | head -1)
    fi
    ## prev date
    prevD=`echo $prevV | cut -d- -f1`
    ## prev build number
    prevN=`echo $prevV | cut -d- -f2`
    ## gen new release number
    newD=`date +%y.%m`
    if [[  $prevD == $newD  ]]; then
        newN=$((prevN + 1))
    else
        newN=0
    fi
    newV=$newD-$newN
    echo "$newV"
}

## $1 repo
## $2 tag
last_release_date() {
    if [ -n "$2" ]; then
        tag="tags/$2"
        else
        tag="latest"
    fi
	local date=$(wget -qO- https://api.github.com/repos/${1}/releases/${tag} | grep created_at | head -n 1 | cut -d '"' -f 4)
	[ -z "$date" ] && echo 0 && return
	date -d "$date" +%Y%m%d%H%M%S
}

## $1 release date
## $2 time span eg "7 days ago"
release_older_than() {
	if [ $(echo -n $1 | wc -c) != 14 ]; then
		echo "wrong date to compare".
	fi
    release_d=$1
    span_d=$(date --date="$2" +%Y%m%d%H%M%S)
    if [ $span_d -ge $release_d ]; then
        return 0
        else
        return 1
    fi
}

## $1 repo:tag
## $2 artifact name
## $3 dest dir
fetch_artifact() {
	[ -f $3/$2 ] && return 0
    local repo_fetch=${1/:*} repo_tag=${1/*:} 
    [ -z "$repo_tag" -o "$repo_tag" = "$1" ] && repo_tag=latest || repo_tag=tags/$repo_tag
	art_url=$(wget -qO- https://api.github.com/repos/${repo_fetch}/releases/${repo_tag} \
		| grep browser_download_url | grep ${2} | head -n 1 | cut -d '"' -f 4)
	[ -z "$(echo "$art_url" | grep "://")" ] && return 1
	## if no destination dir stream to stdo
	if [ "$3" = "-" ]; then
		wget $art_url -qO-
	else
		mkdir -p $3
		if [ $(echo "$2" | grep -E "gz|tgz|zip|xz|7z") ]; then
			wget $art_url -qO- | tar xzf - -C $3
		else
			wget $art_url -qO- | tar xf - -C $3
		fi
		touch $3/$2
	fi
}

## $1 image file path
## $2 mount target
## mount image, ${lon} populated with loop device number
mount_image() {
	umount -Rfd $2
	rm -rf $2 && mkdir $2
	lon=0
	while [ -z "$(losetup -P /dev/loop${lon} $(realpath ${1}) && echo true)" ]; do
		lon=$((lon + 1))
		[ $lon -gt 10 ] && return 1
		sleep 1
	done
	ldev=/dev/loop${lon}
	tgt=$(realpath $2)
	mkdir -p $tgt
	for p in $(find /dev/loop${lon}p*); do
		mp=$(echo "$p" | sed 's~'$ldev'~~')
		mkdir -p $tgt/$mp
		mount -o nouuid $p $tgt/$mp
	done
}

## $1 rootfs
mount_hw() {
	rootfs=$1
	mkdir -p $rootfs
	cd $rootfs
	mkdir -p dev proc sys
	mount --bind /dev dev
	mount --bind /proc proc
	mount --bind /sys sys
	cd -
}

## $1 rootfs
umount_hw() {
	rootfs=$1
	cd $rootfs || return 1
	umount dev
	umount proc
	umount sys
	cd -
}

## $@ apk args
## install alpine packages
apkc() {
	initdb=""
	root_path=$(realpath $1)
	apkrepos=${root_path}/etc/apk
	shift
	mkdir -p ${apkrepos}
	if [ ! -f "${apkrepos}/repositories" ]; then
		cat <<EOF >${apkrepos}/repositories
http://dl-cdn.alpinelinux.org/alpine/latest-stable/main
http://dl-cdn.alpinelinux.org/alpine/latest-stable/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF
		initdb="--initdb"
	fi
	apk --arch x86_64 --allow-untrusted --root ${root_path} $initdb --no-cache $@
}

## $1 ref
## routine pre-modification actions for ostree checkouts
prepare_rootfs() {
	rm -rf ${1}
	mkdir ${1}
	cd $1
	mkdir -p var var/cache/apk usr/lib usr/bin usr/sbin usr/etc
	for l in usr/etc,etc usr/lib,lib usr/lib,lib64 usr/bin,bin usr/sbin,sbin; do
		IFS=','
		set -- $l
		ln -sr $1 $2
		unset IFS
	done
	cd -
}

## $1 ref
## routing after-modification actions for ostree checkouts
wrap_rootfs() {
	[ -z "$1" ] && (
		echo "no target directory provided to wrap_rootfs"
		exit 1
	)
	cd ${1}
	rm -rf var/cache/apk/*
	umount -Rf dev proc sys run &>/dev/null
	rm -rf dev proc sys run
	mkdir dev proc sys run
	cd -
}

## $@ packages to install
install_tools() {
	setup=false
	tools="$@"
	for t in $tools; do
		if [ -z "$(apk info -e $t)" ]; then
			setup=true
			toinst="$toinst $t"
		fi
	done
	$setup && apk add --no-cache $toinst
}

## $1 path to search
## return the name of the first file named with 64numchars
b64name() {
	echo $(basename $(find $1 | grep -E [a-z0-9]{64}))
}

compare_csums() {
	if [ "$new_csum" = "$old_csum" ]; then
		printc "${pkg} already up to update."
		echo $pkg >>file.up
		exit
	fi
}

install_glib() {
	mount -o remount,ro /proc &>/dev/null
	## GLIB
	GLIB_VERSION=$(last_version sgerrand/alpine-pkg-glibc)
	wget -q -O $1/etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/sgerrand.rsa.pub
	wget -q https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIB_VERSION/glibc-$GLIB_VERSION.apk
	if [ -n "$1" ]; then
		apk --root $1 add glibc-$GLIB_VERSION.apk
	else
		apk add glibc-$GLIB_VERSION.apk
	fi
	rm glibc-$GLIB_VERSION.apk
	mount -o remount,rw /proc &>/dev/null
}
## routing to add packages over existing tree
## checkout the trunk using hardlinks
#rm -rf ${ref}
#ostree checkout --repo=${repo_local} --union -H ${ref} ${ref}
### mount ro
#modprobe -q fuse
### overlay over the checkout to narrow pkg files
#rm -rf work ${pkg} over
#mkdir -p work ${pkg} over
#prepare_checkout ${ref}
#mount -t overlay -o lowerdir=${ref},workdir=work,upperdir=${pkg} none over
#apkc over add ${pkg}
### copy new files over read-only base checkout
#cp -an ${pkg}/* ${ref}-ro/
#fusermount -u ${ref}-ro/