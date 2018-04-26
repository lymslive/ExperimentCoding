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

my $wage = 0;
my $result = $dbh->selectcol_arrayref(
	"SELECT LastName
	FROM staff
	WHERE Wage > ? 
	ORDER by Wage",
	undef,
	$wage)
	or die "Failed to select column: ". $dbh->errstr;

print "Poorest: $result->[0], Richest: $result->[-1]\n";

$dbh->disconnect;
