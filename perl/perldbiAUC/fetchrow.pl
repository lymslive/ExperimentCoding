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
	SELECT FirstName, LastName FROM staff
	}) or die "Failed in statement prepare: " . $dbh->errstr;

$sth->execute() or die $dbh->errstr;
# $sth->dump_results();

=pod
while (my @name = $sth->fetchrow_array) {
	print "$name[0] $name[1]\n";
}

# fetch_ref use the same memory for each fetch
# () after 'fetchrow_array*' method is seems optional
while (my $name = $sth->fetchrow_arrayref()) {
	print "$name->[0] $name->[1]\n";
}
=cut

$sth = $dbh->prepare(q{
	SELECT FirstName, LastName, Address, City, State FROM staff
	}) or die "Failed in statement prepare: " . $dbh->errstr;
$sth->execute() or die $dbh->errstr;

while (my $result = $sth->fetchrow_hashref()) {
	print "$result->{FirstName} $result->{LastName}\n",
	"$result->{Address}\n",
	"$result->{City} $result->{State}\n\n";
}

# check got all data normally or break with error?
if ($sth->err) {
	die "Failed to fetch all data: " . $sth->errstr;
}


$dbh->disconnect;
