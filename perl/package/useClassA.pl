#! /usr/bin/env perl
use strict;
use warnings;
use ClassA;

ClassA::method(qw(a b c)); # output: a, b, c
ClassA->method(qw(a b c)); # output: ClassA, a, b, c
ClassA->method
my $obj = ClassA->new();
$obj->method(qw(a b c)); # output: ClassA=HASH(0x1dd2d48), a, b, c
