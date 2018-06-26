#! /usr/bin/perl
use strict;
use warnings;

# local $/ = "\x0d\x0a";
local $/ = "\x0d\x00\x0a\x00";
my $filename = "trans.txt";
my $STR = "STR_GLOBAL_SAVED";
my $str_u16_re = join "\x00", split(//, $STR);

open(my $fh, '<', $filename) or die "cannot open $filename $!";
print "\xff\xfe";
while (<$fh>) {
	# warn "$.\n";
	# warn "$. seen \n" if /$str_u16_re/;
	print if /$str_u16_re/;
}
close($fh);

__END__
qq 群遇到的问题
从一个 utf-16LE 编码的源文件中提取行，字符串ID 对应多国语言翻译的数据文件。
根据常规ID正则匹配，可手动内插 \x00 字节以适应源数据。
但输出文件也要首先输出 \xff\xfe 两字节的大小端标记符。

先前尝试用 enca/ encov 工具转化源文件 trans.txt 为 utf8
或用 vim 设置 fileencoding 后另存，似乎都不全然满意
拉回 windows 操作系统后用记事本打开仍有部分乱码
估计有某些异国文字转 utf8 时出问题？没法全部转？

可用 vim -b trans.txt 打开 :%!xxd 查看16进制，分析源文件的字节流
