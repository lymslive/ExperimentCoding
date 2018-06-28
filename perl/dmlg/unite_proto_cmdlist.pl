#! /usr/bin/perl
# 列出所有命令宏定义
# 宏定义行文本示例：
# <macro name="CS_CMD_HORSE" value="11000" desc="坐骑系统"/>
#
use strict;
use warnings;

chdir("/data/home/tsl/server/protocol/xml");
@ARGV = glob('*.xml');
while (<>) {
	s/^\s*//;
	if (/^\s*<macro\s+name="(CS_CMD_\w+)"\s+value="(\d+)".*\/>/) {
		print sprintf("%6d  %s\t%s\n", $2, $1, "tag $1");
	}
}

