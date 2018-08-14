#! /usr/bin/env perl
package symtable;
use strict;
use warnings;

# use File::Spec;
use File::Find;
print "symbols in package: File::Find\n";
foreach my $key (sort keys %File::Find::) {
	print "$key\n";
}
GetSymbols(\%{File::Find::});

sub GetSymbols
{
	my ($pack_ref, $pack_name) = @_;
	$pack_name //= '';
	print "symbols in package: $pack_name\n";
	foreach my $key (sort keys %$pack_ref) {
		print "$key\n";
	}
}

# 面向对象风格的模块，打印的符号表较少，面向过程的模块，符号表比较多
