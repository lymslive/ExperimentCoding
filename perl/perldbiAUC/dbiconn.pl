#! /usr/bin/env perl
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

print "Hello, Mysql DBI\n";

$dbh->disconnect;
