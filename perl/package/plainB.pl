#! /usr/bin/perl

use strict;
use warnings;

# require 用法
# require plainA.pl; # 不能以 .pl 
# require plainA; # 只查找 plainA.pm
require "plainA.pl"; # 需要用引号
# require "./plainA.pl"; # 也可以显示用相对路径
# . 默认附加到 @INC 搜索中
# 但如果从其他目录中执行脚本，在当前路径中也会找不到 "plainA.pl"

&suba; # 可访问 suba()
# print "$vara from B"; # 不可访问 $vara

my $varb = "var B";
&funa($varb);

&subb() unless defined caller;
# 在 strict 限制下，至少于 & 或 () 调用函数
# subb unless defined caller;

# 如果在 require 进来的 plainA.pl 中已定义 subb
# 这里从定义 subb 没用，无编译运行错误
# 但运行结果是那个文件内的定义，有警告
sub subb
{
	print "$varb\n";
}

subb();

