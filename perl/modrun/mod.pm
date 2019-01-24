#! /usr/bin/env perl
package mod;
use strict;
use warnings;

BEGIN {
	warn "begin in mod.pl of module code\n";
}

use Log::Log4perl qw(get_logger);
#Log::Log4perl->init('log.conf');
my $logger = get_logger();
$logger->error('log error in mod!');

# require "app.pl";
# $app::log->info("share app::log");

sub foo
{
	my ($var) = @_;
	$logger->debug('debug sub foo');
}

1;
__END__
=pod
module 在编译阶段执行，所以函数外的 $logger->error() 执行时未初始化，无输出。
后面程序运行时，所调用的函数内的 logger 有效。

如果在 app.pl 中，将 Log4perl 初始化放在 BEGIN 中，则本模块外层的
$logger->error() 可以被执行。
在日志中看到这阶段的函数名叫 app::BEGIN

=cut
