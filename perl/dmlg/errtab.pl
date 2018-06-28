#! /usr/bin/perl
# 将 svr_err.h 定义的错误码导出表格
# 提取打印错误码整数与注释文本，两个 \t 分隔
# 输入应该适合直接 copy 到 Excel 表格中
#
# 可选参数：错误组 (enum 标签)
#   只打印这个枚举下的错误码
#
# 已知问题：
#   打印在终端模拟器上的 \t 会变成空格
#   无法复制出制表符，只复制出空格

use strict;
use warnings;

my $defenum = shift;
my $on = 1;
$on = 0 if $defenum;
my $curenum = "";
my $curvalue = 0;
my $lstvalue = 0;
my $comment = "";

while (<STDIN>) {
	chomp;
	if (/^\s*enum\s+(\w+)/ && $defenum) {
		$curenum = $1;
		# ($curenum =~ $defenum) ? $on = 1 : $on = 0;
		if ($curenum =~ $defenum) {
			$on = 1;
		}
		else {
			$on = 0;
		}
		# print "$curenum\t$defenum\t$on\n";
	}
	if (/^\s*([A-Z_]+)\s*(=\s*(\d+))?\s*,\s*\/\/\s*(.*)\s*$/ && $on) {
		$curvalue = $3;
		$comment = $4;
		$curvalue = $lstvalue+1 unless $curvalue;
		$lstvalue = $curvalue;
		print "$curvalue\t\t$comment\n";
	}
}

=pod
使用示例：
cat svr_err.h | errtab.pl SwordErr > tmp
vim tmp
复制内容至 excel 表，可能需要使用文本导入向导进行合适的分列
rm tmp

注意：该脚本直接输出中文到终端似乎有乱码
从终端复制 \t 符也会变成多个空格，故用 excel 的导入向导
=cut
