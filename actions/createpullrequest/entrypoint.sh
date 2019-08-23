#!/bin/sh -l
#ls -alh
printenv

if [ -n "$(git status --porcelain)" ]; then

    echo "Git Working Tree is dirty"
	git config -l
	
	echo "configuring git config"
    #branchname=$(cat /proc/sys/kernel/random/uuid)

    git config --global user.email 14359777+uday31in@users.noreply.github.com
    git config --global user.name uday31in
	git config --global hub.protocol https

	git config -l

    remote="uday31in-patch-3"
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
	
	echo "git push -u"
	git push --set-upstream origin uday31in-patch-3
	git push -u 

else
    echo "Git Working Tree Clean. Nothing to Commit"
fi
