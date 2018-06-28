#! /usr/bin/perl
# logcmd.pl 筛选 zone_svr 日志收发包的脚本
# 
# 以 [Head] 开始的包体至空，也包括 [Head] 的上一行
# 从标准输出输出，可用管道或文件重定向与其他 unix 工作联合使用。
#
# 参数：零至多个消息 ID (cmd)
# *) 没有参数，输出所有 cmd 包
# *) +cmd1:cmd2，输出从 cmd1 至 cmd2 之间的包，+ 号可省；cmd2 可省，省略时与 cmd1 同
# *) -cmd1:cmd2，不输出 cmd1 至 cmd2 之间的包
=pod
示例：
假设 logcmd.pl 已在 path 中 ，当前目录是 ~/server/log/zone_svr

# 提取某个日志文件中所有包体结构至临时文件中
 $ logcmd.pl < zone_svr_yyyymmdd.log > tmp.log
 $ cat zone_svr_yyyymmdd.log | logcmd.pl  > tmp.log

# 在终端中即时查看当前日志中某一个 cmd 的包体结构
 $ tail -f zone_svr_yyyymmdd.log | logcmd.pl 1001

# 在终端中即时查看当前日志中某一段 cmd 范围内的包体结构
 $ tail -f zone_svr_yyyymmdd.log | logcmd.pl 1001:1100

# 在终端中即时查看当前日志中某几个特定 cmd 的包体结构
 $ tail -f zone_svr_yyyymmdd.log | logcmd.pl +1001:2001 -1050 -1234 +2009

# 查看当天最近的日志文件，建议在 .bashrc 中添加类似如下的别名
alias tailfe='tail -f `ls -rt *.error | tail -1`'
alias tailfg='tail -f `ls -rt zone_svr_20*.log | tail -1`'
alias tailfr='tail -f `ls -rt rundata*.log | tail -1`'

然后就可用这样的简化命令
tailfg | logcmd.pl
=cut

use strict;
use warnings;

# 分析输入参数
my @include = ();
my @exclude = ();
my $isinclude = 1;
my $to = 0;
my $from = 0;

while ($_ = shift)
{
	if (/^([+-])?(\d+)(:(\d+))?/){
		$isinclude = 1;
		if ($1 && $1 eq '-') {
			$isinclude = 0;
		}
		$from = $2;
		if ($4) {
			$to = $4
		}
		else {
			$to = $from;
		}
		if ($isinclude) {
			push(@include, {from => $from, to => $to});
		}
		else {
			push(@exclude, {from => $from, to => $to});
		}
	}
	else {
		&usage;
		exit 0;
	}
	
}
# &yourinput;

# 主循环处理
my $pkgon = 0;
my $lastline = "";
my @buff = ();
my $cmd = 0;

while (<STDIN>)
{

	if (/^\s+\[Head\]\s*$/) {
		$pkgon = 1;
		@buff = ();
		push(@buff, $lastline);
	}

	$lastline = $_;

	if ($pkgon) {

		push(@buff, $lastline);

		if (/^\s+Cmd=(\d+)\s*$/) {
			$cmd = $1;
		}

		if (not /^\s+[\[\w]+/) {
			$pkgon = 0;
			if (interested($cmd)) {
				print(join("", @buff));
			}
		}
	}
}

# 判断一个 cmd 编号是否在参数范围内
sub interested
{
	my $icmd = shift;
	my $tf = 0;

	if (@include) {
		foreach my $href (@include) {
			if ($icmd >= $href->{from} && $icmd <= $href->{to}) {
				$tf = 1;
				last;
			}
		}
	}
	else {
		$tf = 1;
	}
	
	if (@exclude) {
		foreach my $href (@exclude) {
			if ($icmd >= $href->{from} && $icmd <= $href->{to}) {
				$tf = 0;
				last;
			}
		}
	}

	return $tf;
}

sub usage
{
	print <<EOF;
logcmd.pl [+|-]cmd1[:cmd2]

argument +cmd1:cmd2, print pkg whoes cmd-id between cmd1 and cmd2
argument -cmd1:cmd2, omit pkg whoes cmd-id between cmd1 and cmd2
NOTE:
* '+' is default sign, can be omited
* if no any '+' arguments, all pkg is selected but in '-' arguments
* ':cmd2' is also optional to specify exactly one cmd-id
EOF
}

sub yourinput
{
	my $i = 0;
	print("include cmd:");
	foreach my $h (@include) {
		print(" $h->{'from'}:$h->{'to'}");
		$i++;
	}
	print(" : $i\n");
	
	$i = 0;
	print("exclude cmd:");
	foreach my $h (@exclude) {
		print(" $h->{from}:$h->{to}");
		$i++;
	}
	print(" : $i\n");
	
	exit 0;
}

