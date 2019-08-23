#!/bin/sh -l
ls -alh
printenv

if [ -n "$(git status --porcelain)" ]; then
  echo "there are changes";
else
  echo "Git Working Tree Clean. Nothing to Commit";
fi