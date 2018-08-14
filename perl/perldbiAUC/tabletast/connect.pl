#! /usr/bin/env perl
use strict;
use warnings;
use DBI;

# alias xsql='mysql -u gctest -pgctest -h 192.168.0.40 -A --default-character-set=utf8 trade'

my $driver = "mysql";
my $dsn = "database=trade;host=192.168.0.40";
my $username = "gctest";
my $password = "gctest";

my $dbh = DBI->connect("dbi:$driver:$dsn", $username, $password, 
	{ AutoCommit => 1 })
	or die "Failed to connect to dbi: $DBI::errstr";

print "Hello, Mysql DBI\n";

$dbh->disconnect;
