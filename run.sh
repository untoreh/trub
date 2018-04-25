#!/bin/sh
. ./functions.sh

## prepare
printc "preparing..."
./prepare.sh

## init the repo
printc "initializing the repo..."
./repo.sh

## the tree of files
printc "growing the tree..."
./grow.sh

## update image from github
printc "building image..."
./build-update.sh
