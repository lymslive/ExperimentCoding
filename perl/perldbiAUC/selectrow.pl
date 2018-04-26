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

=pod
Selecting a single row or column
my @row = $dbh->selectrow_array($statement, \%attr, @bind_values);
=cut

my $staffid = 12345;
=pod
my @result = $dbh->selectrow_array(
	"SELECT FirstName, LastName, Wage
	FROM staff
	WHERE StaffID = ?",
	undef,
	$staffid
	) or die "Failed to select row: ". $dbh->errstr;

print $result[0];
=cut

my $resultref = $dbh->selectrow_arrayref(
	"SELECT FirstName, LastName, Wage
	FROM staff
	WHERE StaffID = ?",
	undef,
	$staffid
	) or die "Failed to select row: ". $dbh->errstr;

print $resultref->[0];

my $hashref = $dbh->selectrow_hashref(
	"SELECT FirstName, LastName, Wage
	FROM staff
	WHERE StaffID = ?",
	undef,
	$staffid
	) or die "Failed to select row: ". $dbh->errstr;

print $hashref->{FirstName};

$dbh->disconnect;
