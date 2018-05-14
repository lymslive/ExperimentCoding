#! /usr/bin/perl

use strict;
use warnings;

# hash 可直接赋值给列表，键值对平坦化
my %hash = (a => 1, b => 2, c => 3);
my @list = %hash;

print join(' ', @list) . "\n";
foreach my $x (@list) {
	print "$x\n";
}

foreach my $y (%hash) {
	print "$y\n";
}

print 0+@list;
print "\n";

# 有错误
print 0+%hash;
print "\n";
