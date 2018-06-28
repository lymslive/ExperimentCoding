#! /usr/bin/perl
# 将 macro 宏定义值依次编号
# 宏定义行文本示例：
# <macro name="CM_CMD_HORSE" value="11000" desc="坐骑系统"/>
# 已明确指定 value 值的不变，value="0" 占位的则依次编号
# 用法：
# 采用标准输入输出，在 vim 中须选定过滤
# :'<,'>! macronum.pl
# 过滤全文也要选定全文
#
use strict;
use warnings;

my $cmd = 0;
my $lastcmd = 0;
while (<STDIN>) {
	if (/^\s*<macro\s+name="\w+"\s+value="(\d+)".*\/>/) {
		if ($1 > 0) {
			$lastcmd = $1;
		}
		else {
			$lastcmd++;
			s/value="\d+"/value="$lastcmd"/;
		}
	}
	print;
}

