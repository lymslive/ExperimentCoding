#! /usr/bin/perl

use strict;
use warnings;
use Net::MySQL;

my $mysql = Net::MySQL->new(
	hostname => 'localhost',
	database => 'test',
	user => 'root',
	password => ''
);

$mysql->query(q{
	INSERT INTO staffphone (StaffID, PhoneNumber) VALUES (12349, '02 3232 3232')
	});
printf "Affected rows: %d\n", $mysql->get_affected_rows_length;

$mysql->query(q{
	SELECT StaffID, PhoneNumber FROM staffphone
	});
my $record_set = $mysql->create_record_iterator;
while (my $record = $record_set->each) {
	printf "StaffID: %s PhoneNumber: %s\n", $record->[0], $record->[1];
}

$mysql->close;
