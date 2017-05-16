#!/bin/bash
source functions.sh

repo="trub"
tree="tree"

cd /srv
rm -rf ${repo} ${tree}
mkdir -p ${repo} ${tree}
ostree --repo=${repo} --mode=archive-z2 init

ostree --repo=${repo} commit -s $(date)'-build' -b trunk --tree=dir=${tree}