#! /usr/bin/env perl
# 调用 wget 下载一本书，如果未指定书目录，则自动找一个未下载完的书
# 只打印 wget 命令字符串到标准输出，需管道至 bash 正式运行
# 命令行参数为网站首页或某书首页，当前目录下应该有网站域名的本地目录
# 用法示例：
# perl biquge-downone.pl https://www.biquta.com/2_2691 | bash
# perl biquge-downone.pl https://www.biquta.com | bash

use strict;
use warnings;

my $url = shift or die "#need a url argument\n";
my ($http, $host, $book);

if ($url =~ m|(https?)://([\w.]+)/([\d_]+)?/?|) {
	$http = $1;
	$host = $2;
	$book = $3;
}
else {
	die "#error argument, seem not url\n";
}

if (!$book) {
	$book = incomplete_book($host);
}

if ($book) {
	# print "$book\n";
	$url = "$http://$host/$book/";
	# print "$url\n";
	print wget_cmd($url) . "\n";
}
else {
	print "#not find book to download\n";
}

####################################
exit 0;
####################################

# 拼接 wget 命令
# 后台递归下载一层，模拟 firefox 间隔秒，忽略 /robots.txt
sub wget_cmd
{
	my ($url) = @_;
	my $roboff = "-e robots=off";
	# my $ua = '--user-agent="Mozilla/5.0 (X11; Ubuntu; Linu…) Gecko/20100101 Firefox/65.0"';
	my $ua = '--user-agent=Firefox/65.0';
	my $now = qx(date +%Y%m%d_%H%M%S);
	chomp($now);
	my $log = "wget-log.$now";
	return "wget -rpb -nv -nc -np -w1 $roboff -o $log $ua $url";
}

# 查找一个未下载完的书
sub incomplete_book
{
	my ($basedir) = @_;

	my $base_len = length($basedir) + 1;
	while (<$basedir/*>) {
		next unless -d $_;
		my $subdir = substr($_, $base_len);
		next unless $subdir =~ /^[0-9_]+$/;
		# print "$subdir\n";

		my @htmls = <$basedir/$subdir/*.html>;
		if (scalar(@htmls) < 4) {
			return $subdir;
		}
	}
	return undef;
}

# 查找所有未下载完的书
sub incomplete_all
{
	my ($basedir) = @_;
	my $books = [];

	my $base_len = length($basedir) + 1;
	while (<$basedir/*>) {
		next unless -d $_;
		my $subdir = substr($_, $base_len);
		next unless $subdir =~ /^[0-9_]+$/;
		# print "$subdir\n";

		my @htmls = <$basedir/$subdir/*.html>;
		if (scalar(@htmls) < 4) {
			push(@$books, $subdir);
		}
	}
	return $books;
}

