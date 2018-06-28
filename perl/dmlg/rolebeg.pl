#! /usr/bin/perl
# 分析中一个玩家的初始行为日志
# 输入文本最好是已被 grep 或其他工具提取的单个玩家的日志片断
# 用于分析玩家首日主线行为节奏
# 目前包括：升级、主线接取、功能开启

use strict;
use warnings;

use Date::Parse;

sub parse_role_log
{
	my $role_id = shift;

	LOG_INPUT:
	while (my $log = <>) {
		chomp($log);

		# 判定所记录的 RoleID
		next LOG_INPUT if $log !~ m/Role:\s*(\d+)\s*!$/xms;
		my $this_role_id = $1;
		if ($role_id) {
			next LOG_INPUT if $role_id != $this_role_id;
		}
		else {
			$role_id = $this_role_id;
		}

		my ($time_label, $event_type, $event_value)
		= $log =~ m{
			^
			\[ (.*?) \] \s* # [时间]
			\[ .*? \] \s*   # [ERROR]
			\[ .*? \] \s*   # [文件位置]
			.*?\| .*?\| .*?\| \s* # 三部分竖线分隔信息
			([^:]+): \s* (\d+), \s* # 事件：值
			Role:\s*\d+\s*!  # 末尾字符
			$
		}xms;

		next LOG_INPUT unless $event_value;

		my $time_value = str2time($time_label);
		print "$time_label, $time_value, $event_type, $event_value\n";
	}
	
}

if (not caller) {
	parse_role_log();
}

1;

=pod
输入文件示例行：
[时间标签][ERROR   ][文件位置] 101272|Marry|8103|Finish main task: 18, Role: 角色号
其中 | 之前的部分是标准 log 文本
时间标签格式：20160605 16:53:40.972442
角色号是64位整数，约18位十进数字

目前自定义的日志事件：
接收主线 => Accept main task: 
完成主线 => Finish main task: 
玩家升级 => Levelup: 
功能开启 => Funciton Open: 
=cut
