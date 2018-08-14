#! /usr/bin/env perl
package symtable;
use strict;
use warnings;

use lib "$ENV{HOME}/notebook/x";
use NoteBook;

print "Hello package\n";

print "symbols in package: NoteBook\n";
foreach my $key (sort keys %NoteBook::) {
	print "$key\n";
}
# output: 多一个 BEGIN

require "datedb.pl";
print "symbols in package: datedb.pl\n";
foreach my $key (sort keys %datedb::) {
	print "$key\n";
}

use File::Spec;
print "symbols in package: File::Spec\n";
foreach my $key (sort keys %File::Spec::) {
	print "$key\n";
}

