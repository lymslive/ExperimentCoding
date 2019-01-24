#! /usr/bin/env perl
# 业务代码
package bus;
use strict;
use warnings;

BEGIN {
	warn "begin in bus.pl of business code\n";
}

# our app::EASY_LOG;
# our app::log;

if ($app::EASY_LOG) {
	use Log::Log4perl qw(:easy);
	# Log::Log4perl->easy_init($ERROR);
	ERROR("I've got something to say!'");
}
else {
	use Log::Log4perl qw(get_logger);
	#Log::Log4perl->init('log.conf');
	my $logger = get_logger();
	$logger->error('log another error!');
}

# require "app.pl";
$app::log->info("share app::log");

my $LOG = $app::log;
$LOG->info("using alias logger object");

1;

__END__
=pod
被 require 的业务代码，BEGIN 与 ERROR 语句在编译阶段不会被执行 (perl -c)
正常运行时 (perl app.pl) 会被执行

如果在调用者 app.pl 中先初始化 Log4perl ，再 require 其他脚本，
则其他脚本内不用再 init ，但要 use 导入必要的函数。

被调用的业务代码，不建议反向再 require "app.pl"
但是单独用 perl -c 检测语法时，会报警告
也没法用 our 前置声明，直接语法错误
写在本地 package bus; 之前也没用。

如果使用共享 $app::log 写起来略长，可赋值给一个 my 变量
=cut
