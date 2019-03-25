#! /usr/bin/env perl
=pod
提取头文件的错误常量定义（及其尾注释），生成 sql 脚本，用于插入错误表
结果打印至标准输出，可重定向或直接管理至 mysql 
用法示例：
./head2error.pl tfberror.h > tfberror.sql
./head2error.pl tfberror.h | mysql ....

./head2error.pl -service usermgr tfberror.h > tfberror.sql
额外选项指定错误码所从属的服务组别，默认 common
=cut

use strict;
use warnings;

use Getopt::Long;

my $TABLE = 'trade.t_error_config';
my $group = 'common';

my $result = GetOptions("service=s" => \$group);

# const int kSuccess = 0;							//成功
my $reconst = qr{const\s+int\s+(\w+)\s*=\s*([-+]?\d+)\s*;\s*//\s*(.+)};
while (<>) {
	if ($_ =~ $reconst) {
		my $symbol = $1;
		my $error = $2;
		my $errstr = $3;
		output($error, $errstr, $symbol, $group);
	}
}

sub output
{
	my ($error, $errstr, $symbol, $service) = @_;
	
	my $sql = <<EOF;
INSERT $TABLE SET
F_error = $error,
F_errstr = '$errstr',
F_symbol = '$symbol',
F_service = '$service';
EOF
	print $sql, "\n";
}
