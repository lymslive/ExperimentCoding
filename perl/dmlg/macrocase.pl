#! /usr/bin/perl
# 将 macro 宏定义值依次转化为 case: 语句
#
use strict;
use warnings;

while (<STDIN>) {
	if (/^\s*<macro\s+name="(\w+)"\s+value="(\d+)"\s+desc="(.*)".*\/>/) {
		print "case $1: // $2. $3\n";
		print "break;\n";
	}
}

