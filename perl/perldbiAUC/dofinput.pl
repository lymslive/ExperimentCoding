#! /usr/bin/perl

use strict;
use warnings;
use DBI;

my $driver = "mysql";
my $dsn = "database=test";
my $username = "root";
my $password = "";

my $dbh = DBI->connect("dbi:$driver:$dsn", $username, $password, 
	{ AutoCommit => 1 })
	or die "Failed to connect to dbi: $DBI::errstr";

print "input staffID and lastname\n";
my $StaffID = <STDIN>;
my $LastName = <STDIN>;
chomp($StaffID, $LastName);

$dbh->do("UPDATE staff SET LastName = ? WHERE StaffID = ?", undef, $LastName, $StaffID)
	or die $dbh->errstr;

$dbh->disconnect;
