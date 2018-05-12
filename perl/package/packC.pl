#! /usr/bin/perl

use strict;
use warnings;

# 用 FindBin 模块后，可在任意目录启动脚本，按相对路径引用模块
use FindBin qw($Bin);
use lib "$Bin"; # 与当前脚本同目录可引用
# use lib "$Bin/lib"; # 与当前脚本目录的子目录 lib/
# use lib "$Bin/../lib"; # 与当前脚本目录的兄弟目录 ../lib/


# 试用 require

require packA; # 正确，会找 packA.pm
# require "packA"; # 错误，只找 packA 文件
# require "packA.pm"; # 引号内要明确文件全名

# 需指定 packA 前缀
# &suba;
# &funa($varb);
&packA::suba;

# 不能访问 packA 中的 my 变量
my $vara = "VAR A";
# my $packA::vara = "VAR A";
# print "$packA::vara from packB\n";
print "$vara from packB\n";
