#! /usr/bin/env perl
# 提取一书的正文内容，保存为一个 txt 文档
# 输入参数为目录名，输出文档取目录名加 .txt，可选指定其他文件名
# 用法示例：
# perl biquge-txt.pl www.biquta.com/2_2691/ [2_2691.txt]
#
# HTML 文档格式
# 标题 <h1>
# 正文 <div id="content">
# 假设目录下各章节 id 是有序的

use strict;
use warnings;

# 解释命令行参数
my $book_dir = shift or die "# error, need a book dir name!";
$book_dir =~ s|/$||;
my $book_name;
if ($book_dir =~ m|([^/]+)$|) {
	$book_name = $1;
}
die "# error, need a book dir name!" unless $book_name;
my $txt_file = shift || "$book_name.txt";

# 获取所有 html 文档的列表
my @html_files = sort grep { $_ !~ m|index\.html$|i} <$book_dir/*.html>;
# print "$_\n" for @html_files;

# 输出至文件
my $file_out = $txt_file;
open(my $fh_out, '>', $file_out) or die "cannot open $file_out $!";
foreach my $html_file (@html_files) {
	print $fh_out chapter_text($html_file);
	print $fh_out "\n";
}
close($fh_out);

# 打印终端提示信息
my $num_file = scalar @html_files;
print "done: $num_file *.html > $txt_file \n";

########################################
exit 0;
########################################

# 提取一章的内容
sub chapter_text
{
	my ($html_file) = @_;
	my ($chapter_title, $chapter_body);
	my ($content_begin, $content_end);
	
	open(my $fh, '<', $html_file) or die "cannot open $html_file $!";
	while (<$fh>) {
		if ($_ =~ m|<h1>(.+)</h1>|i) {
			$chapter_title = $1;
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
# $chapter_title

$chapter_body
EOF
}
