#! /usr/bin/perl
# 输入：TabNamesDef.h 中的行
# #define Tab_T ConfigTable<tagT>::Instance()
# 输入：*ConfigMgr 类中初始化的 load 语句
use strict;
use warnings;

while (<STDIN>)
{
	chomp;
	&output($1) if /define\s+Tab(\w+)\s+ConfigTable.*/;
}

sub output
{
	my $name = shift;
	print <<EOF;
if (0 != Tab${name}\->load("$name",))
{
	LOG_ERR("?? connot load Tab$name");
	return -1;
}
EOF
}

