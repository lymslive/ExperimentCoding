#! /usr/bin/perl
# 将 svr_err.h 定义的错误码枚举明确排序
#
# 可选参数：错误组 (enum 标签)
#   只修改这个枚举下的错误码
#

use strict;
use warnings;

my $defenum = shift;
my $on = 1;
$on = 0 if $defenum;

my $curenum = "";
my $curvalue = 0;
my $lstvalue = 0;
my $comment = "";
my $errname = "";

while (<STDIN>) {
	chomp;
	if (/^\s*enum\s+(\w+)/ && $defenum) {
		$curenum = $1;
		if ($curenum =~ $defenum) {
			$on = 1;
		}
		else {
			$on = 0;
		}
	}
	if (/^\s*([A-Z_]+)\s*(=\s*(\d+))?\s*,\s*\/\/\s*(.*)\s*$/ && $on) {
		$errname = $1;
		$curvalue = $3;
		$comment = $4;
		$curvalue = $lstvalue+1 unless $curvalue;
		$lstvalue = $curvalue;
		print "\t$errname = $curvalue,\t//$comment\n";
	}
	else
	{
		print "$_\n";
	}
}

