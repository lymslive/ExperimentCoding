#! /usr/bin/perl
# ������һ����ҵĳ�ʼ��Ϊ��־
# �����ı�������ѱ� grep ������������ȡ�ĵ�����ҵ���־Ƭ��
# ���ڷ����������������Ϊ����
# Ŀǰ���������������߽�ȡ�����ܿ���

use strict;
use warnings;

use Date::Parse;

sub parse_role_log
{
	my $role_id = shift;

	LOG_INPUT:
	while (my $log = <>) {
		chomp($log);

		# �ж�����¼�� RoleID
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
			\[ (.*?) \] \s* # [ʱ��]
			\[ .*? \] \s*   # [ERROR]
			\[ .*? \] \s*   # [�ļ�λ��]
			.*?\| .*?\| .*?\| \s* # ���������߷ָ���Ϣ
			([^:]+): \s* (\d+), \s* # �¼���ֵ
			Role:\s*\d+\s*!  # ĩβ�ַ�
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
�����ļ�ʾ���У�
[ʱ���ǩ][ERROR   ][�ļ�λ��] 101272|Marry|8103|Finish main task: 18, Role: ��ɫ��
���� | ֮ǰ�Ĳ����Ǳ�׼ log �ı�
ʱ���ǩ��ʽ��20160605 16:53:40.972442
��ɫ����64λ������Լ18λʮ������

Ŀǰ�Զ������־�¼���
�������� => Accept main task: 
������� => Finish main task: 
������� => Levelup: 
���ܿ��� => Funciton Open: 
=cut
