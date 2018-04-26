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

$dbh->do("INSERT INTO staffphone (StaffID, PhoneNumber) VALUES (12351, '02 9999 9999')")
	or die "Failed to insert row: " . $dbh->errstr;

$dbh->do("DELETE FROM staffphone WHERE StaffID = 12349 AND PhoneNumber = '02 9333 3334'")
	or die "Failed to delete row: " . $dbh->errstr;

$dbh->do("UPDATE staff SET Wage = 79 WHERE StaffID = 12346")
	or die "Failed to update row: " . $dbh->errstr;

$dbh->disconnect;
