#! /usr/bin/perl

use strict;
use warnings;

my $vara = "var A";

&suba unless defined caller;

sub suba
{
	print "$vara\n";
}

sub subbb
{
	# __FILE__ 不能放在引号中
	print "$vara in " . __FILE__  . __LINE__ . "\n";
}

sub funa
{
	my $var = shift;
	print "$var in plainA.pl:funa()\n";
}

# 最好显示返回 1，如果之前的最后语句也能返回 ture 也可以，但不好保证
# 0;
1;
