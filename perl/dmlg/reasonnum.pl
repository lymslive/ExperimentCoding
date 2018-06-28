#! /usr/bin/perl
# 将 svr_op_reason.h 定义的原因码枚举明确排序
#
#

use strict;
use warnings;

my $curenum = "";
my $curvalue = -1;
my $lstvalue = -1;
my $comment = "";
my $opname = "";

while (<STDIN>) {
	chomp;
	if (/^\s*([A-Z_]+)\s*,\s*$/) {
		$opname = $1;
		# $curvalue = $3;
		# $comment = $4;
		# $curvalue = $lstvalue+1 unless $curvalue;
		# $lstvalue = $curvalue;
		$curvalue++;
		print "\t$opname = $curvalue,\n";
	}
	else
	{
		print "$_\n";
	}
}

