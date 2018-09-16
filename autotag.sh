#!/bin/bash

# This script tags the state of the current branch and optionally pushes
# tags to the remote.  It also configures the local git repo to include tags
# during git push.

date=`date +%Y.%m.%d_%H.%M.%S`
base=`git rev-parse --show-toplevel`
pid=$$

# ignore signals, so users don't stop in an intermediate state
trap "" SIGINT SIGQUIT SIGTSTP

# Save modification times of files with uncommitted changes.  The 2nd sed command
# deletes surrounding double quotes; the 3rd sed command removes a level of
# backslashes in backslashed characters.
files=`git status -uno --porcelain | sed -e "s/^...//" -e 's/^\"\\(.*\\)\"$/\1/' -e 's/\\\\\(.\\)/\1/g'`
IFS=$'\n'	# split on newline only
for file in $files; do
    if [ -e $file ]; then
	(cd $base; touch -r $file $file.autotag.$pid)
    fi
done

# stash local changes
stash1=`git stash list`
git stash > /dev/null
stash2=`git stash list`
if [ "$stash1" != "$stash2" ]; then
    git stash apply > /dev/null
fi

# create temporary commit
git commit -am compile-${date} --allow-empty > /dev/null

if [ $? -eq 0 ]; then
    # create tag for the temporary commit
    git tag -a compile-${date} -m ""

    # Push tag (if requested on the command line).  Allow this to be killed
    # (without killing autotag.sh).
    if [ "$1" = "push" ]; then
	(trap - SIGINT SIGQUIT SIGTSTP; git push --tags >& /dev/null)
    fi

    # undo temporary commit
    git reset --hard HEAD~ > /dev/null
fi

# restore local changes (if any)
if [ "$stash1" != "$stash2" ]; then
    git stash pop > /dev/null
fi

# restore modification times
for file in $files; do
    if [ -e $file.autotag.$pid ]; then
	(cd $base; touch -r $file.autotag.$pid $file; rm $file.autotag.$pid)
    fi
done

# configure git to push tags (in addition to the current branch)
config=`git config --get-all remote.origin.push`
if [[ ! $config =~ refs/tags/\* ]]; then
    git config --add remote.origin.push refs/tags/*
fi
if [[ ! $config =~ HEAD ]]; then
    git config --add remote.origin.push HEAD
fi
