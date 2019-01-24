#! /usr/bin/env perl
# 程序主入口脚本
package app;
use strict;
use warnings;

our $EASY_LOG = 0;

use FindBin;
use lib "$FindBin::Bin";

BEGIN {
	warn "begin in app.pl\n";

our $log;
if ($EASY_LOG) {
	use Log::Log4perl qw(:easy);
	Log::Log4perl->easy_init($ERROR);
	ERROR("I've got something to say!'");
}
else {
	use Log::Log4perl qw(get_logger);
	Log::Log4perl->init('log.conf');
	$log = get_logger();
	$log->error('log one error!');
}

} # end of BEGIN

use mod;
require "bus.pl";

mod::foo();

__END__
=pod
perl -c app.pl
输出
begin in app.pl
app.pl syntax OK

perl app.pl
输出
begin in app.pl
begin in bus.pl of business code
2019/01/24 09:22:30 I've got morething to say!'
2019/01/24 09:22:30 I've got something to say!'

编译时执行 BEGIN{} ，但 require 的文件不在编译阶段
运行阶段先执行 require 文件的代码

Log4perl 初始化建议放在 BEGIN{} 块中，方便在加载的其他模块中直接使用
否则要延迟到函数调用阶段。

将 $log 对象设为 our ，在其他业务代码脚本中可直接用 $app::log-> 方法
但避免在业务脚本中再 require "app.pl" ，因 app.pl 未加载完，循环加载会重复执行 app.pl

如果整个程序所有脚本都不用 package 命名空间，可共享 $main::log ，简写为 $log .
=cut
