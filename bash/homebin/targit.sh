#! /bin/bash
# 打包当前 git 仓库
# 进入 git 仓库目录调用该脚本
# 将仓库内容打包成 *.tgz ，忽略 .gitignore 中指定的文件

name=$(basename $(pwd))
exclude=--exclude-vcs\ --exclude-backups
exclude=$exclude\ --exclude-from='.gitignore'
exclude=$exclude\ --exclude='*.tgz'

echo tar czf ${name}.tgz ${exclude} '*'
tar czf ${name}.tgz ${exclude} *
