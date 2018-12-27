#! /usr/bin/env perl
use strict;
use warnings;

use MPEG::Audio::Frame;
use MP3::Splitter;

# 参数：文件名 切分时长秒数
my $filename = shift or die "expect a *.mp3 audio file";
my $subtime = shift || 60;

my $sumtime = mp3_time($filename);
my $curtime = 0;

# 构造切分参数列表
my @subaudios = ();
push(@subaudios, [0, $subtime]);
$curtime += $subtime;
while ($curtime < $sumtime) {
	push(@subaudios, ['>0', $subtime]);
	$curtime += $subtime;
}

# 调用模块方法切分音频，输出文件名自动加前缀数字：01_$filename
my $option = {};
# my $option = {verbose=>1};
mp3split($filename, $option, @subaudios);

# 计算音频总时长
sub mp3_time
{
	my ($filename) = @_;
	
	open(my $fh, '<', $filename) or die "cannot open $filename $!";
	my $time = 0;
	while(my $frame = MPEG::Audio::Frame->read($fh)) {
		$time += $frame->seconds();
	}
	close($fh);

	return $time;
}

1;
