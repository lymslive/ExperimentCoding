#! /usr/bin/perl
# 将 svr_op_reason.h 定义的错误码枚举明确排序
#

use strict;
use warnings;

my $filename = '/data/home/tsl/server/src/logic_comm/svr_op_reason.h';
open(my $FILE, '<', $filename) or die "cannot open $filename";

my $enumon = 0;
my $enumoff = 0;
my $enumnum = 0;

while (<$FILE>) {
	chomp;
	if (/^\s*enum\s+(\w+)/) {
	    $enumon = 1;
	}

	next unless $enumon;

	if (/^\s*([A-Z_]+)\s*,\s*$/ && $enumon) {
		print "$enumnum\t$1\n";
		$enumnum++;
	}
}

