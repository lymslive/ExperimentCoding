#! /usr/bin/perl
# 将 macro 宏定义值转为 tab 分隔的报表
# 宏定义行文本示例：
# <macro name="CM_CMD_HORSE" value="11000" desc="坐骑系统"/>
# 输出：
# $value \t $desc \t $name
#
use strict;
use warnings;

my $cmd = 0;
my $lastcmd = 0;
while (<STDIN>) {
	if (/^\s*<macro\s+name="(\w+?)"\s+value="(\d+?)"\s+desc="(.*?)"\s*\/>/) {
		print "$2\t$3\t$1\n";
	}
}

