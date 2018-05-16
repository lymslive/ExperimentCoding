#! /usr/bin/perl
package userB;
use strict;
use warnings;

require "lib.pl";

libfun();

sub UBfun
{
	libfun();
}

&UBfun unless defined caller;

# 单独使用 userB 没问题
