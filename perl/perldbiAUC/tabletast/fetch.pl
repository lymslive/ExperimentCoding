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
	{ AutoCommit => 1, mysql_enable_utf8 => 1})
	or die "Failed to connect to dbi: $DBI::errstr";

# 或用以下语句声明编码
# my $sql = qq{SET NAMES 'utf8'};
# $dbh->do($sql);

print "Hello, Mysql DBI\n";

# sql 语句模板，查询一个表的列定义
my $stp = <<SQL;
select COLUMN_NAME, COLUMN_TYPE, COLUMN_KEY, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_COMMENT
from information_schema.columns
where table_schema = ? and table_name = ?
SQL

my $dbname = 'trade';
my $tbname = 't_user_bind_card';

my $sth = $dbh->prepare($stp) or die $dbh->errstr;
$sth->execute($dbname, $tbname) or die $dbh->errstr;

while (my $col = $sth->fetchrow_hashref()) {
	my $name = $col->{COLUMN_NAME};
	my $type = $col->{COLUMN_TYPE};
	my $bkey = $col->{COLUMN_KEY};
	my $null = $col->{IS_NULLABLE};
	my $deft = $col->{COLUMN_DEFAULT} // 'NULL';
	my $comt = $col->{COLUMN_COMMENT};
	print "$name = $type, $bkey, $null, $deft // $comt\n";
}

$dbh->disconnect;
