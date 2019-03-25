#! /usr/bin/env perl
use strict;
use warnings;

#use Text::CSV;

my $TABLE = 'trade.t_error_config';
my $renum = qr/^\s*[-+]?\d+/;

while (<>) {
	my ($error, $errstr, $symbol, $service) = split("\t");
	next unless $error =~ $renum;
	my $sql = <<EOF;
INSERT $TABLE SET
F_error = $error,
F_errstr = '$errstr',
F_symbol = '$symbol',
F_service = '$service';
EOF
	print $sql, "\n";
}

