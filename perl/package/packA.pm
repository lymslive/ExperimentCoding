#! /usr/bin/perl

use strict;
use warnings;

package packA;

my $vara = "var A";
our $uA = "our A";
# 在 strict 下不允许裸用变量，必须指定包名
# $nuA = "no our A";

&suba unless defined caller;

sub suba
{
	print "$vara\n";

	# my 变量 vara 不是 $packA::vara
	# print "$packA::vara\n";
	# our 变量是别名
	print "$packA::uA\n";
	print "$uA\n";
	print "$nuA\n";
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
