#! /usr/bin/perl
=pod
根据模板文本生成多段文件。
输入语料格式：

<Text Template>
__SEP__
<Argv Line>

模板文本中含 $1 $2 占位符
参数行，参数用 tab 分隔，对应替换

目前只支持 $1 一个参数
=cut

use strict;
use warnings;

my @tplines = ();
my $seped = 0;

my $SEP_PATTERN = qr/^\s*__SEP__\*$/;
my $SEP_ARGUMENT = qr/\t/;

while (<STDIN>) {
	# 提取保存模板
	if (m/$SEP_PATTERN/) {
		$seped = 1;
		next;
	}

	if ($seped == 0) {
		push(@tplines, $_);
		next;
	}

	# 提取参数
	chomp;
	my @args = split($SEP_ARGUMENT, $_);
	next unless @args;

	# 输出模板
	foreach my $line (@tplines) {
		my $newline = $line;
		$newline =~ s/\$1/$args[0]/g;
		print $newline;
	}
	
}

