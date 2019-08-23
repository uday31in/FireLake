#!/bin/sh -l
ls -alh
printenv

if [ -n "$(git status --porcelain)" ]; then

    echo "Git Working Tree is dirty"

	echo 
    #branchname=$(cat /proc/sys/kernel/random/uuid)

    git config --global user.email {{GITHUB_CONTEXT.event.pusher.email }}
    git config --global user.name {{GITHUB_CONTEXT.event.pusher.name }}

    remote="uday31in-patch-1"
    git ls-remote --exit-code --heads origin $remote
    if [ $? -eq 0 ]; then
        echo "branch $remote exists"
        git checkout $remote
    else
        echo "branch $remote do not exists"
        git checkout -b $remote
    fi
    
    echo "git status"
    git status

    echo "git add ."
    git add .

    echo "git status"
    git status

    echo "git commit"
    git commit -m "Automated PR from Build"

    echo "git status"
    git status
	
	echo "git push"
	git push

else
    echo "Git Working Tree Clean. Nothing to Commit"
fi
