#! /usr/bin/perl
# 根据模板生成一系列子类
=pod
## 输入方本示例：

class CBehaveWingRank : public CBehaveInterpretor
{
<接口声明列表>
};

__SEP__
<macro name="BEHAVIOR_TYPE_LIFE_CYCLE" value="21" desc="转生"/>
<macro name="BEHAVIOR_TYPE_WENZHI_UP" value="22" desc="文职达到职位"/>
<macro name="BEHAVIOR_TYPE_JUNXIAN_UP" value="23" desc="军衔达到职位"/>
.....
<许多行>

## 处理方法：

__SEP__ 行之前的文本当作原位模板示例
之后每个非空行当作生成修改参数，每行将对模板复制修改一份
原位模板保留，是有效文本内容

本脚本主要对参数行中的宏名作为替换类名，并保留简明注释

=cut

use strict;
use warnings;

my @tplines = ();
my $seped = 0;

my $SEP_PATTERN = qr/__SEP__/;
my $ARG_PARRERN = qr/<macro name="(\w+)" value="(\d+)" desc="(.*)"\/>/;

while (<STDIN>) {
	# chomp;

	# 标记模板结束
	if (m/$SEP_PATTERN/) {
		$seped = 1;
		# print "__BEGIN__\n";
		print(join("", @tplines));
		next;
	}

	# 保存 __SEP__ 之前的行，包括空行
	if ($seped == 0) {
		push(@tplines, $_);
		next;
	}

	# 过滤不能识别的参数行
	next unless m/$ARG_PARRERN/;

	# 提取参数
	my $mname = $1;
	my $idval = $2;
	my $desc = $3;

	# 修饰类名
	my $cname = $mname;
	$cname =~ s/BEHAVIOR_TYPE//;
	$cname =~ s/_?([A-Z])([A-Z]+)/\u$1\L$2\E/g;

	# 输出模板
	print "// $mname\[$idval\] $desc\n";
	foreach my $line (@tplines) {
		my $newline = $line;
		$newline =~ s/CBehave(\w+)/CBehave$cname/;
		print $newline;
	}
	
}

# print(join("", @tplines));
# print "__END__\n";
