#! /usr/bin/perl

use strict;
use warnings;

package packB;

my $varb = "var B";
&subb unless defined caller;

sub subb
{
	print "$varb in " . __FILE__  . __LINE__ . "\n";
}

# 以上正常使用
# 试用 use

use packA;

# 需指定 packA 前缀
# &suba;
# &funa($varb);
&packA::suba;
&packA::funa($varb);

# 不能访问 packA 中的 my 变量
my $vara = "VAR A";
# my $packA::vara = "VAR A";
# print "$packA::vara from packB\n";
print "$vara from packB\n";

# 可以访问 our 变量，实则是全名变量的别名
print "${packA::uA} from packB\n";
$packA::uA = 333;
print "$packA::uA from packB\n";
