#! /usr/bin/env perl
use strict;
use warnings;
use DBI;

my $driver = "mysql";
my $dsn = "database=trade;host=192.168.0.40";
my $username = "gctest";
my $password = "gctest";

my $dbh = DBI->connect("dbi:$driver:$dsn", $username, $password, 
	{ AutoCommit => 1 })
	or die "Failed to connect to dbi: $DBI::errstr";

print "Hello, Mysql DBI\n";

# 简单 do 操作，只返回影响行数
my $doret = 0;

$doret = $dbh->do("desc t_user_bind_card");
print "do desc resturn: $doret\n"; ## 10 列数
$doret = $dbh->do("show create table t_user_bind_card");
print "do desc resturn: $doret\n"; ## 1

$dbh->disconnect;
