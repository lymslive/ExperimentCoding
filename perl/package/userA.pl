#! /usr/bin/perl
package userA;
use strict;
use warnings;

require "lib.pl";
require "userB.pl";
# 引入 userB, 其内再次引入 lib 时，跳过，出错
# 而 libvar 与 libfun 被引入于 userA 空间中
# 在 userB.pl 中直接使用 libfun 出错，因为全名为 userA::libfun()

&libfun();

&userB::UBfun();
