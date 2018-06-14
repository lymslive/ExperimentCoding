#! /usr/bin/perl
use strict;
use warnings;

our $libvar = "lib var";

sub libfun
{
	print "$libvar\n";
}

# 作为 lib 设计于将来用于被引入
# 没有 package 声明，被引入后所在的命名空间取决于使用者
# 这在循环引用时有问题。
