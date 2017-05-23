#!/bin/bash

gem install travis
source functions.sh

handle_deploy() {
	if [ "$TRAVIS_TAG" -a -f file.up ]; then
		GIT_REMOTE=$(git remote show origin | grep -i "push.*url" \
			| sed -r 's~.*push.*?:[ \s]+(.*?://)(.*)$~\1'$GIT_USER:$GIT_TOKEN'@\2~i')
		git tag -d $TRAVIS_TAG
		git push --delete $GIT_REMOTE $TRAVIS_TAG
		travis cancel $TRAVIS_BUILD_NUMBER --no-interactive -t $TRAVIS_TOKEN
		sleep 3600
	fi
}

handle_tags() {
	## since a build has been deployed rebuild dependend images on the /trees repo
	git clone --depth=1 https://$GIT_USER:$GIT_TOKEN@github.com/$trees_repo && cd $(basename $trees_repo)
    ## tag_prefix defined in yml env:
	git tag ${tag_prefix}-$(md)
	git push --tags
}
