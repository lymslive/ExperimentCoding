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

my $sth = $dbh->prepare(q{
	SELECT FirstName, LastName, ProjectName, Allocation
	FROM staff s, projects p
	WHERE s.StaffID = p.StaffID AND ProjectName = ?
	ORDER BY ProjectName
	}) or die "Failed in statement prepare: " . $dbh->errstr;

foreach my $project ('ABC', 'XYZ', 'NMO') {
	$sth->execute($project)
		or die "Failed to execute statement: ". $dbh->errstr;
	$sth->dump_results();
}

$dbh->disconnect;
