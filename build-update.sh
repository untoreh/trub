#!/bin/bash

source functions.sh

rem_repo="untoreh/trub"
repo="trub"
pkg="trub"
artifact="trub.tar"
csum_artifact="trub.sum"
delta_artifact="delta-trub.tar"
tree="tree"
ref="trunk"

## confirm we made a new tree
if [ ! "`find tree/* -maxdepth 0 | wc -l`" -gt 0 ]; then
    echo "newer tree not grown. (tree folder is empty)"
    exit 1
fi

install_tools "ostree util-linux wget"

## if we have an artifact (beware the slash)
if $(fetch_artifact $rem_repo /$artifact prev); then
    cmt=$(b64name prev)

    ## apply the scratch delta to the empty repo
    rev=$(ostree --repo=$repo static-delta apply-offline prev/${cmt})
    ## name the commit
    ostree --repo=$repo refs --delete $ref
    ostree --repo=$repo refs --create=$ref $rev
fi

## commit the recently grown tree on top of the previous image in the repo
newrev=$(ostree --repo=$repo commit -s $(date)'-build' -b $ref --tree=dir=${tree})

## compare checksums of previous and grown trees, abort if still up to date
old_csum=$(fetch_artifact $rem_repo /${csum_artifact} -)
new_csum=$(ostree --repo=$repo ls $ref -Cd | awk '{print $5}')
compare_csums

## then generate the sparse,scratch archived deltas and scratch checksum
ostree --repo=${repo} static-delta generate $ref --inline --min-fallback-size 0  \
 --filename=${newrev}
tar cf $delta_artifact $newrev && rm $newrev
ostree --repo=${repo} static-delta generate $ref --inline --min-fallback-size 0  \
 --filename=${newrev} --empty
tar cf $artifact $newrev && rm $newrev
echo $new_csum >${csum_artifact}
