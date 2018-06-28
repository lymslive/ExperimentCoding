#! /bin/bash
# 递归读取目录及其子目录（不包括文件）
# http://www.jb51.net/article/48832.htm
#
function read_dir(){
for file in `ls $1`
do
	if [ -d $1"/"$file ]
	then
		echo $1"/"$file
		read_dir $1"/"$file
	# else
		# echo $1"/"$file
	fi
done
}

if [ -d $1 ]
then
	cd $1
	read_dir $(pwd)
else
	echo "expect a folder name"
fi

