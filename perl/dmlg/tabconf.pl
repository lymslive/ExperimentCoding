#! /usr/bin/perl
# 处理 resource/xml 下的配置表
# 提取配制表名，每个 strct 的 name 都视为一个表名
# 输出用于 TabNamesDef.h 的宏定义
#define Tab_T ConfigTable<tagT>::Instance()
#
# 可能手动删除多余的中间结构体，而不作为配置表的

use strict;
use warnings;

my @confignames = ();
# TabXxxxxx 名字长度
my $TABLENGTH = 30;

while (<STDIN>)
{
	print;
	push @confignames, $1 if /struct name="(\w+)"/;
}

END{
	&tabdefine;
}

sub tabdefine
{
	for my $name (@confignames){
		my $tabname = "Tab$name";
		my $pad = $TABLENGTH - length($name);
		$tabname .= " " x $pad if $pad > 0;
		print "#define $tabname        ConfigTable<tag$name>::Instance()\n"
	}
}

