#! /usr/bin/env perl
# 录音识别支持
package Speech;
use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Basename;

use MPEG::Audio::Frame;
use MP3::Splitter;
use LWP::UserAgent;
use JSON;
use MIME::Base64;
use Encode;

# 应用参数
my $APP_ID = "15270466";
my $API_KEY =  "2zj1EWbaiWWLlyxmFsKMZRj8";
my $SECRET_KEY = "Yr4eePOXAqVSyGEvd1yM3QjR1wGisjf4";

# api 地址参数
my $TOKEN_URL =  "https://openapi.baidu.com/oauth/2.0/token";
my $VOP_URL = "http://vop.baidu.com/server_api";
# token 有效其为一个月
my $TOKEN = "24.8b88242af907bdb2fa177de2f4656f31.2592000.1548472354.282335-15270466";

my $DEBUG = 0;

# 识别录音并打分
sub ScoreMp3
{
	my ($mp3file, $stdtext) = @_;
	unless ($stdtext) {
		warn "standar text not provided." if $DEBUG;
		return 0;
	}
	my $text = TextMp3($mp3file);
	unless ($text) {
		warn "speech text fail to get." if $DEBUG;
		return 0;
	}
	return text_score($stdtext, $text);
}

# 将 mp3 识别为文字
sub TextMp3
{
	my ($mp3file) = @_;

	my $fullname = abs_path($mp3file);
	my $basename = basename($fullname);
	my $dirname = dirname($fullname);

	# my $token = get_token();
	my $token = $TOKEN;
	if (!$token) {
		return '';
	}

	# 切分模块需要转到音频文件路径
	my $oldcwd = getcwd();
	chdir($dirname);

	my $text = '';
	my $frag_count = mp3_split($basename, 60);
	if ($frag_count < 1) {
		chdir($oldcwd);
		return '';
	}
	elsif ($frag_count == 1) {
		warn "short mp3, direct speech: $basename\n" if $DEBUG;
		$text = mp3_speech($token, $basename);
	}
	else {
		warn "long mp3, split speech\n" if $DEBUG;
		for (my $i = 1; $i <= $frag_count; $i++) {
			my $mp3file = sprintf("%02d_%s", $i, $basename);
			my $frag_text = mp3_speech($token, $mp3file);
			if ($frag_text) {
				warn "done speech: $mp3file\n" if $DEBUG;
				$text .= $frag_text;
				unlink $mp3file;
			}
			else {
				warn "fail speech: $mp3file\n" if $DEBUG;
			}
		}
	}

	chdir($oldcwd);
	print "speech text: $text\n" if $DEBUG;
	return $text;
}

###
# 私有实现函数
###

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

# 切分 mp3 ，返回切成的文件数
sub mp3_split
{
	my ($filename, $subtime) = @_;

	my $sumtime = mp3_time($filename);
	my $curtime = 0;

	# 短视频，不需要切割
	if ($sumtime < $subtime) {
		return 1;
	}

	my $frag_count = int($sumtime / $subtime) + 1;

	# 构造切分参数列表
	my @subaudios = ();
	my $first = [0, $subtime];
	my $middle = ['>0', $subtime];
	my $last = ['>0', 'INF'];
	push(@subaudios, $first);
	for (my $count = 1; $count < $frag_count - 1; $count++) {
		push(@subaudios, $middle);
	}
	push(@subaudios, $last);
	
	my $option = {};
	# my $option = {verbose=>1};
	mp3split($filename, $option, @subaudios);

	return $frag_count;
}

# 获取 Access Token 授权
sub get_token
{
	my $token_url_req = "$TOKEN_URL?grant_type=client_credentials&client_id=$API_KEY&client_secret=$SECRET_KEY";
	warn "token req: $token_url_req\n" if $DEBUG;
	my $ua = LWP::UserAgent->new();
	my $response = $ua->post($token_url_req);
	if ($response->is_success) {
		my $res_str = $response->decoded_content();
		warn "token req: $res_str\n" if $DEBUG;
		my $json = JSON->new();
		my $res_json = $json->decode($res_str);
		my $token_str = $res_json->{access_token};
		return $token_str;
	}
	warn "fail to get token from baidu: ", $response->status_line, "\n" if $DEBUG;
	return "";
}

# 向百度请求语音识别
# 入参：token 与 音频文件
# 出参：识别结果文字
sub speech
{
	my ($token, $audio_file) = @_;

	my $content = '';
	# open(my $fh, '<', $audio_file) or die "cannot open $audio_file $!";
	open(my $fh, '<', $audio_file) or return '';
	{
		local $/ = undef;
		$content = <$fh>;
	}
	close($fh);

	my $content_base64 = encode_base64($content, '');
	my $content_size = length($content);
	my $req = {
		format => "pcm",
		rate => 16000,
		channel => 1,
		token => $token,
		cuid => "hehuo-yqds",
		speech => $content_base64,
		len => $content_size,
	};

	my $json = JSON->new();
	my $req_json = $json->encode($req);
	# warn $req_json, $CR;

	my $header = HTTP::Headers->new( Content_Type => 'application/json; charset=utf8', );
	my $http_request = HTTP::Request->new(POST => $VOP_URL, $header, $req_json);
	my $ua = LWP::UserAgent->new();
	my $response = $ua->request($http_request);

	unless ($response->is_success) {
		my $status = $response->status_line;
		warn "Baidu Response Fial: $status\n" if $DEBUG;
	}
	my $res_str = $response->decoded_content();
	warn "Baidu Response: $res_str\n" if $DEBUG;

	my $res_json = $json->decode($res_str);
	if ($res_json->{err_no} != 0) {
		return '';
	}

	return $res_json->{result}->[0];
}

sub mp3_speech
{
	my ($token, $mp3file) = @_;
	
	# 转码为 pcm ，百度语音要求的格式
	my $pcmfile = "$mp3file.pcm";
	my $cmd = "ffmpeg -y  -i $mp3file  -acodec pcm_s16le -f s16le -ac 1 -ar 16000 $pcmfile";
	if (system($cmd) != 0) {
		warn "system fial: ffmpeg convert mp3 to pcm: $!\n" if $DEBUG;
		return '';
	}
	unless(-f $pcmfile && -s $pcmfile) {
		warn "system fial: ffmpeg convert mp3 to pcm, result file empty\n" if $DEBUG;
		return '';
	}

	# 语音识别，成功后删除临时转换文件
	my $text =  speech($token, $pcmfile);
	if ($text) {
		print "got speech text: $text\n" if $DEBUG;
		unlink $pcmfile;
	}

	return $text;
}

# 比较两段文件并打分，参数1为标准文本，参数2为测试文本
# 返回五星级评分
sub text_score
{
	my ($str1, $str2) = @_;
	$str1 =~ s/\s//g;
	$str2 =~ s/\s//g;

	my $ustr1 = decode('utf8', $str1);
	my $ustr2 = decode('utf8', $str2);
	my @std = split(//, $ustr1);
	my @test = split(//, $ustr2);
	my $std = scalar(@std);
	my $test = scalar(@test);
	my %std = ();
	my %test = ();
	map { $std{$_}++ } @std;
	map { $test{$_}++ } @test;

	warn "std char count: $std\n" if $DEBUG;
	warn "test char count: $test\n" if $DEBUG;
=for debug
	foreach my $key (keys %std) {
		warn "$key : $std{$key}\n";
	}
	foreach my $key (keys %test) {
		warn "$key : $test{$key}\n";
	}
=cut

	my $result = 0;
	foreach my $key (keys %std) {
		next unless $test{$key};
		$result += $std{$key} < $test{$key} ? $std{$key} : $test{$key};
	}

	my $base = $std > $test ? $std : $test;
	my $star = int($result/$base * 5 + 0.5);
	warn "correct chars: $result; stars: $star\n" if $DEBUG;

	return $star;
}

###
# 测试函数
###

sub main
{
	my ($mp3file, $stdfile) = @_;
	unless (-s $mp3file && -s $stdfile) {
		die "expect mp3file and stdfile";
	}
	
	$DEBUG = 1;
	my $stdtext = '';
	{
		open(my $fh, '<', $stdfile) or die "cannot open $stdfile $!";
		local $/ = undef;
		$stdtext = <$fh>;
		close($fh);
	}

	my $star = ScoreMp3($mp3file, $stdtext);
	print "done scored $star stars\n";
}

&main(@ARGV) unless defined caller;
1;
__END__
