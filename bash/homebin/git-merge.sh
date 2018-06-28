#! /usr/bin/env bash
# work on git dev branch
# tmporaay switch to master, merge dev, and then back to dev

git pull
git checkout master
git merge dev
git push
git checkout dev
