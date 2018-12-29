#! /usr/bin/env perl
package textcmp;
use strict;
use warnings;

use Encode;

my $file1 = shift;
my $file2 = shift or die "expect tow files to compare";

my $str1 = get_filecontent($file1);
my $str2 = get_filecontent($file2);

text_compare($str1, $str2);

sub get_filecontent
{
	my ($filename) = @_;
	open(my $fh, '<', $filename) or die "cannot open $filename $!";
	local $/ = undef;
	my $content = <$fh>;
	close($fh);
	return $content;
}

sub text_compare
{
	my ($str1, $str2) = @_;
	$str1 =~ s/\s//g;
	$str2 =~ s/\s//g;
	
	my $ustr1 = decode('utf8', $str1);
	my $ustr2 = decode('utf8', $str2);
	my @std = split(//, $ustr1);
	my @test = split(//, $ustr2);
	my $std = scalar(@std);
	my $test = scalar(@test);
	my %std = ();
	my %test = ();
	map { $std{$_}++ } @std;
	map { $test{$_}++ } @test;

	warn "std char count: $std\n";
	foreach my $key (keys %std) {
		warn "$key : $std{$key}\n";
	}
	warn "test char count: $test\n";
	foreach my $key (keys %test) {
		warn "$key : $test{$key}\n";
	}
	
	my $result = 0;
	foreach my $key (keys %std) {
		next unless $test{$key};
		$result += $std{$key} < $test{$key} ? $std{$key} : $test{$key};
	}

	my $base = $std < $test ? $std : $test;
	my $star = int($result/$base * 5 + 0.5);
	warn "correct chars: $result; stars: $star\n";

	return $star;
}
