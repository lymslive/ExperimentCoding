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

# dump_results 用于查看输出

print "mysql> desc t_user_bind_card;\n";
my $sth = $dbh->prepare("desc t_user_bind_card") or die "Failed in statement prepare: ". $dbh->errstr;
$sth->execute() or die "Failed to execute statement ". $dbh->errstr;
$sth->dump_results();
## 与 mysql 交互命令相比，没有表格线，单引号括起每个值，类似 csv

print "mysql> show create table t_user_bind_card;\n";
$sth = $dbh->prepare("show create table t_user_bind_card") or die "Failed in statement prepare: ". $dbh->errstr;
$sth->execute() or die "Failed to execute statement ". $dbh->errstr;
$sth->dump_results();
## 这个只有一行两列，CREATE TABLE 字符串太长，被截断

$dbh->disconnect;
