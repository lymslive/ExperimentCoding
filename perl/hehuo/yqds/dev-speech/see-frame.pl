#! /usr/bin/env perl
use strict;
use warnings;

use MPEG::Audio::Frame;
use MP3::Splitter;

my $filename = shift or die "expect a *.mp3 audio file";
open(my $fh, '<', $filename) or die "cannot open $filename $!";
my $alltime = 0;
my $fidx = 0;
while(my $frame = MPEG::Audio::Frame->read($fh)) {
	++$fidx;
	print $frame->offset(), ": ", $frame->bitrate(), "Kbps/", $frame->sample()/1000, "KHz\n";
	my $time = $frame->seconds();
	$alltime += $time;
	print "[$fidx] time: $time, sumup: $alltime\n";
}
close($fh);

exit(0);

=pod
按 MPEG::Audio:Frame 示例代码查看音频 mp3 的 frame 信息
似乎是解析出文件内的每一帧
音频总时长要将每一帧的时长加起来
=cut
