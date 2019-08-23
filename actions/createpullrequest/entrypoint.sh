#!/bin/sh -l
ls -alh
printenv

if [ -n "$(git status --porcelain)" ]; then
  
  echo "Git Working Tree is dirty"
  
  echo "git branch"
  git branch
  
  echo "git status"
  git status
  
  echo "git add ."
  git add .
  
  echo "git status"
  git status
  
  echp "git commit"  
  git commit -m "Automated PR from Build"
  
else
  echo "Git Working Tree Clean. Nothing to Commit";
fi