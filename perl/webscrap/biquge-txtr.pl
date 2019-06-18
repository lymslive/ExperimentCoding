#! /usr/bin/env perl
# 递归处理整个本地网站目录，将每章节的 html 转为 txt
# 输入参数为目录名
# 用法示例：
# perl biquge-txt.pl www.biquta.com/
#

use strict;
use warnings;

use File::Find;
use Cwd 'abs_path';

# 解释命令行参数
my $site_dir = shift or die "# error, need a site dir name!";
$site_dir = abs_path($site_dir);

# 直接指定文件
if ($site_dir =~ /index\.html$/) {
	print chapter_index($site_dir);
}
elsif ($site_dir =~ /\.html$/) {
	print chapter_text($site_dir);
}
else {
	# 递归目录
	die "# error: $site_dir not a dir!" unless -d $site_dir;
	find(\&wanted, $site_dir);
}


# 打印终端提示信息
print "done: $site_dir \n";

########################################
exit 0;
########################################

# File::Find 回调函数，处理每个文件
sub wanted
{
	my ($var) = @_;
	
	print "$File::Find::name\t";
	if ($File::Find::name =~ m|([\d_]+)/(\S+)\.html?$|i) {
		my $book = $1;
		my $file = $2;

		my $output = "";
		if ($file =~ m|^[\d_]+$|i) {
			$output = chapter_text($File::Find::name);
		}
		elsif ($file =~ m|^index$|i) {
			$output = chapter_index($File::Find::name);
		}

		if ($output) {
			my $file_out = $File::Find::dir . "/$file.txt";
			open(my $fh_out, '>', $file_out) or die "cannot open $file_out $!";
			print $fh_out $output;
			close($fh_out);

			print "->\t$file_out\n";
			return;
		}
	}

	print "-- skiped\n";
}

# 提取章节列表
# html 格式，在 <dd> 元素内，<dt> 分卷 <dl> 整个列表
# 输出格式：每行章节id及标题，此外分卷目录名也输出
sub chapter_index
{
	my ($html_file) = @_;
	my ($book_title, $book_body);
	my ($list_begin, $list_end);
	
	open(my $fh, '<', $html_file) or die "cannot open $html_file $!";
	while (<$fh>) {
		if ($_ =~ m|<h1>(.+)</h1>|i) {
			$book_title = "# $1";
			next;
		}
	
		if ($_ =~ m|<dt>|i && $_ !~ m|最新章节|) {
			$list_begin = 1;
			$book_body = "";
			# warn "begin list: $. $_\n";
		}
		if ($list_begin) {
			if ($_ =~ m|</dl>|i) {
				$list_end = 1;
				# warn "end of list: $. $_\n";
				last;
			}
			if ($_ =~ m|<dt>\s*(\S+)\s*</dt>|i) {
				$book_body .= "\n## $1\n\n";
			}
			elsif ($_ =~ m|<dd>\s*<a.*href="(\S+)\.html?">\s*(.+)\s*</a></dd>|i) {
				my $href = $1;
				my $chapter = $2;
				$book_body .= "* $href\t$chapter\n";
			}
		}
	}
	close($fh);
	
	return <<EOF;
$book_title
$book_body
EOF
}

# 提取一章的内容
# HTML 文档格式
# 标题 <h1>
# 正文 <div id="content">
sub chapter_text
{
	my ($html_file) = @_;
	my ($chapter_title, $chapter_body);
	my ($content_begin, $content_end);

	open(my $fh, '<', $html_file) or die "cannot open $html_file $!";
	while (<$fh>) {
		if ($_ =~ m|<h1>(.+)</h1>|i) {
			$chapter_title = "# $1";
			next;
		}

		if ($_ =~ m|<div id="content">|i) {
			$content_begin = 1;
			$chapter_body = "";
			next;
		}
		next if $content_end;
		if ($content_begin) {
			if ($_ =~ m|</div>|i) {
				$content_end = 1;
				last;
			}
			next if ($_ =~ m|<script>|i);
			s/^\s*//;
			s/\s*$//;
			$_ =~ s|<br/><br/>|\n|ig;
			$chapter_body .= $_;
		}
	}
	close($fh);

	return <<EOF;
$chapter_title

$chapter_body
EOF
}
