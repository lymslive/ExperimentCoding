#! /usr/bin/env perl
# 提取一页（章）的正文内容
# 向标准输出，需要时用 > 定向保存结果。
# 用法示例：
# perl biquge-txt.pl www.biquta.com/2_2691/3148070.html > 3148070.txt
#
# 标题 <h1>
# 正文 <div id="content">
use strict;
use warnings;

my $html_file = shift or die "# error, need a file.html name!";

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

print <<EOF;
# $chapter_title

$chapter_body
EOF
