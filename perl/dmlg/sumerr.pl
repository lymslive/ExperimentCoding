#! /usr/bin/perl
# 统计错误文件
# 与 ./staterr.pl 功能相同，在其基础上修改，
# 不向标准错误输出打印 warn 信息
# 同时按错误数从大到小排序
# 在日志量比较大时，运行较慢

use strict;
use warnings;

# 错误字符串示例
my %error_str = ();
# 每个错误出现次数
my %error_num = ();
# 不同错误个数
my $error_cnt = 0;

while (<>){
	chomp;
	my $log = $_;

	my ($time_label, $file_location, $error_string) = 
	$log =~ m{
		^
		\[ (.*?) \] \s* # [timeleabel]
		\[ERROR \s*? \] \s*   # [ERROR]
		\[ (.*?) \] \s*   # [file pos]
		.*?\| .*?\| .*?\| (.*) # error string
		$
	}xms;
	next unless $error_string;

	# warn $file_location;

	my ($file_name, $func_name) = 
	$file_location =~ m{\((.*?)\)\s*\((.*?)\)}xms;
	next unless $func_name;

	# warn $file_name;

	my ($file_line) = 
	$file_name =~ m{([^/]*)$}xms;

	if (defined $error_num{$file_line}) {
		$error_num{$file_line} += 1;
	}
	else{
		$error_num{$file_line} = 1;
		$error_str{$file_line} = $error_string;

		# print some info to stderr
		$error_cnt++;
		# warn "$error_cnt\t$file_line\n";
	}
} 

# warn "Summary:\n";
# warn "Count\tFile:line\tString\n";

foreach my $key (reverse sort { $error_num{$a} <=> $error_num{$b} } keys %error_num) {
	print "$error_num{$key}\t$key\t$error_str{$key}\n";
}

=pod
=h1 usage
./staterr.pl error_log_file_name[s] [> output_filename]
cat error_log_file_name[s] | ./staterr.pl [> output_filename]
./staterr.pl error_log_file_name[s] | sort -k 1 -rn | less

=h1 desc
接收标准输入，输入参数一般是错误日志文件名，可通配符指定多个；
结果写入标准输出，可重定向文件。

结果文件格式；每行三列，以一个制表符分隔
第一列是每种错误出现的频次；
第二列是每种错误出现的文件名:行号标记
第三列是该种错误首次出现的错误字符串示例

分析大日志文件时需要一定时间，因而向标准错误打印一些中间结果提示进度。
=cut
