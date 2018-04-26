#! /usr/bin/perl

use strict;
use warnings;
# using system or open to access the database's shell directly
# but bad idea

my $username = 'root';
my $password = '';
my $database = 'test';

# open piped file for select:
# open (SELECT, "mysql -u $username -p $password $database -e 'SELECT * from staff' |") or die "Failed for some reason: $!";
open (SELECT, "mysql $database -e 'SELECT * from staff' |") or die "Failed for some reason: $!";

my @results = <SELECT>;
close SELECT;

print "@results\n";

# system for update:
system(qq{
	mysql $database -e "INSERT INTO staffphone (StaffID, PhoneNumber) Values (12345, '02 2222 2222')"
	});
die "Error: $?" if $?;
