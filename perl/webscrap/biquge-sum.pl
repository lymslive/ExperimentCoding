#! /usr/bin/env perl
# 统计参数指定的目录或当前目录下的一级子目中，各有多少个 html 文档
# 适用于笔趣阁下载网站，每本书的子目录名为纯数字或下划线，如 2_2691/
# 初如从首页爬时，每本书目录下应该至少有一个 index.html 文件，其余也以数字id为
# 文件名。故只统计像书名目录的子目录，如果该目录下只有1-2或很少 html 文件时，
# 可估计为该书未下完，可能需要重新下载。
# 向标准输出，需要时用 > 定向保存结果。
# 每行两列，书目录及已下载文档数，类似 "$subdir \t $htmls"
# 用法示例：
# perl biquge-sum.pl www.biquta.com > biquta-sum.txt
# perl biquge-sum.pl > biquta-sum.txt
use strict;
use warnings;

# use Cwd;
# my $basedir = shift || getcwd();

my $basedir = shift || ".";
# my @subdirs = <$basedir/*>;
# print "$_\n" for @subdirs;

my $base_len = length($basedir) + 1;
while (<$basedir/*>) {
	# print "$_\n" if -d $_;
	next unless -d $_;
	my $subdir = substr($_, $base_len);
	next unless $subdir =~ /^[0-9_]+$/;
	# print "$subdir\n";

	my @htmls = <$basedir/$subdir/*.html>;
	my $html_num = scalar(@htmls);
	print "$subdir\t$html_num\n";
}

