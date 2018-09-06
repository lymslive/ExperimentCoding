#! /usr/bin/env perl
package ClassA;
use strict;
use warnings;

sub method
{
	print join(", ", @_);
	print "\n";
}

sub new
{
	my $class = shift;
	my $self = {name => $class};
	bless $self, $class;
	return $self;
}

1;
__END__
