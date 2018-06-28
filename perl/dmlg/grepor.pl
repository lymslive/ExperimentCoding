#! /usr/bin/perl
# 打印符合配置文件中任一行的标准输入流
# 类似 grep -E 'regexp1 \| regexp2 \| regexp3 ...'
# 如果感兴趣的行很多，不方便在命令行输入，则可用此脚本
# 用法：cat *.log | grepor.pl [conf-file]
# 默读配置文件为 grepor.regexp 
# 每一行表示要匹配的正则表达式，但是忽略 # 开始的行，认为是注释
# 只要匹配任一行，就打印至标准输出
# 没有配置文件时，或配置文件中没有一行有效正则表达式时，打印所有行

use strict;
use warnings;

# 命令行参数为配置文件
my $conf = 'grepor.regexp';
$conf = shift if @ARGV > 0;

# 读取配置文件，每行为一个正则表达式
my @regexp = ();
if (open(my $fh_conf, '<', $conf)) {
	while (<$fh_conf>) {
		next if /^\s*#/;
		next if /^\s*$/;
		chomp;
		push(@regexp, $_);
	}
}

# 主循环处理
while (<STDIN>) {
	# chomp;
	print, next if @regexp <= 0;
	foreach my $reg (@regexp) {
		print, last if /$reg/;
	}
}
