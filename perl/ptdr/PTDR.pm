#! /usr/bin/perl

use strict;
use warnings;
use Carp qw(carp croak);

# this package setting
package PTDR;
use Exporter 'import';
our @EXPORT_OK = qw(parsefile saveptdr get_ptdr);

# use XML::Parse::Style::Subs
use XML::Parser;
my $tdr_parser = XML::Parser->new(Style => 'Subs');

sub parsefile{
	my $file = shift;
	$tdr_parser->parsefile($file);
}

sub parsestr{
	my $xml = shift;
	$tdr_parser->parse($xml);
}

# record the last complex element in xml-stream
my $EMPTY = q{};
my %last_element = (
	metalib => $EMPTY,
	group => $EMPTY,
	struct => $EMPTY,
	union => $EMPTY,
);

# tdrlib datastruct in perl hash
my %tdrlib = (
	name => $EMPTY,
	macro_of => {},
	group_of => {},
	struct_of => {},
	union_of => {},
);

sub get_ptdr{
	return \%tdrlib;
}

use Data::Dumper;
sub saveptdr {
	my $out_file = shift;

	# default output file
	if (not $out_file) {
		$out_file = "$tdrlib{name}.dumper";
	}

	if ($out_file eq '-') {
		print Dumper(\%tdrlib);
	}
	else{
		open my $hf_out, '>', $out_file or die "Can't open '$out_file': $!";
		print $hf_out Dumper(\%tdrlib);
		close $hf_out;
	}
}

# element handles
## metalib
sub metalib{
	my ($expat, $element, %attr) = @_;

	if ($last_element{metalib}) {
		if ($element ne $last_element{metalib}) {
			warn "metalib name($element) dismatch the last one($last_element{metalib})\n";
		}
	}
	else{
		$last_element{metalib} = $element;
		$tdrlib{name} = $attr{name};
	}

	warn "+ $element $attr{name}\n";
}

sub metalib_{
	my ($expat, $element) = @_;
	warn "- $element\n";
}

## macro
sub macro{
	my ($expat, $element, %attr) = @_;
	if (!$last_element{group}) {
		$tdrlib{macro_of}->{$attr{name}} = \%attr;
	}
	else{
		push @{$tdrlib{group_of}->{$last_element{group}}}, \%attr;
	}
}

sub macro_{
	my ($expat, $element) = @_;
}

## entry
sub entry{
	my ($expat, $element, %attr) = @_;

	if ($last_element{struct}) {
		push @{$tdrlib{struct_of}->{$last_element{struct}}}, \%attr;
	}
	elsif ($last_element{union}) {
		push @{$tdrlib{union_of}->{$last_element{union}}}, \%attr;
	}
	else{
		warn "Bared entry $attr{name} occurs!\n";
	}
}

sub entry_{
	my ($expat, $element) = @_;
}

## macrosgroup
sub macrosgroup{
	my ($expat, $element, %attr) = @_;

	my $name = $attr{name};

	$tdrlib{group_of}->{$name} = [];
	$last_element{group} = $name;

	warn "+ $element $name\n";
}

sub macrosgroup_{
	my ($expat, $element) = @_;
	$last_element{group} = $EMPTY;

	warn "- $element\n";
}

## struct
sub struct{
	my ($expat, $element, %attr) = @_;

	my $name = $attr{name};

	$tdrlib{struct_of}->{$name} = [];
	$last_element{struct} = $name;

	warn "+ $element $name\n";
}

sub struct_{
	my ($expat, $element) = @_;
	$last_element{struct} = $EMPTY;

	warn "- $element\n";
}

## union
sub union{
	my ($expat, $element, %attr) = @_;

	my $name = $attr{name};

	$tdrlib{union_of}->{$name} = [];
	$last_element{union} = $name;

	warn "+ $element $name\n";
}

sub union_{
	my ($expat, $element) = @_;
	$last_element{union} = $EMPTY;

	warn "- $element\n";
}

# test
sub HelloTDR{
	print "Hello TDR!\n";
}

# run alone
if (not caller) {
	HelloTDR();
	# print "@XML::Parser::Expat::Encoding_Path\n";

	foreach my $file (@ARGV) {
		parsefile($file);
	}

	saveptdr();
}

1;
=pod

=for Problem
初始不支持编码为 gb2312 的 xml 文件，gb2312.enc 需在以下目录中
	print "@XML::Parser::Expat::Encoding_Path\n";
	/usr/lib64/perl5/XML/Parser/Encodings

=cut
