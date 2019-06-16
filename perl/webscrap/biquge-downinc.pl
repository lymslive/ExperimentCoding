#! /usr/bin/env perl
# 调用 wget 自动下载未下载完的书
# 命令行参数为网站首页，当前目录下应该有网站域名的本地目录
# 用法示例：
# perl biquge-downone.pl https://www.biquta.com

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

my $books = incomplete_all($host);
foreach my $book (@$books) {
	$url = "$http://$host/$book/";
	my $cmd = wget_cmd($url);
	my $out = qx($cmd);
	while(1) {
		# 等上一个 wget 下载完再下载另一本书
	}
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
	my $log = "wget-log.biquge";
	return "wget -rpb -nv -nc -np -w1 $roboff -a $log $ua $url";
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

