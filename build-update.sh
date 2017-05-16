#!/bin/bash
source functions.pine

remote_repo="untoreh/trub"
repo="trub"
artifact="trub.tar"
delta_artifact="delta-trub.tar"
tree="tree"
ref="trunk"

## confirm we made a new tree
if [ ! "`find tree/* -maxdepth 0 | wc -l`" -gt 0 ] ; then
    echo "newer tree not grown. (tree folder is empty)"
    exit 1
fi

install_tools "ostree util-linux wget"

fetch_artifact $repo $artifact prev

cmt=$(b64name prev)

## apply the scratch delta to the empty repo
rev=$(ostree --repo=$repo static-delta apply-offline ${cmt})
## name the commit
ostree --repo=$repo refs --delete $ref
ostree --repo=$repo refs --create=$ref $rev

## commit the recently grown tree on top of the previous image in the repo
newrev=$(ostree --repo=$repo commit -s $(date)'-build' -b $ref --tree=dir=${tree})

## prune older commits
ostree prune --repo=$repo --refs-only --keep-younger-than="3 months ago"

## then generate the sparse and scratch delta and archive
ostree --repo=${repo} static-delta generate $ref --inline --min-fallback-size 0 \
    --filename=${newrev}
tar cf $delta_artifact $newrev && rm $newrev
ostree --repo=${repo} static-delta generate $ref --inline --min-fallback-size 0 \
    --filename=${newrev} --empty
tar cf $newrev && rm $newrev
