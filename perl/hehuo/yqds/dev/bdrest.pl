#! /usr/bin/env perl
package bdrest;
use strict;
use warnings;

# use HTTP::Request;
# use HTTP::Headers;
use LWP::UserAgent;
use JSON;
use MIME::Base64;
use Encode;

# 运用参数
my $APP_ID = "15270466";
my $API_KEY =  "2zj1EWbaiWWLlyxmFsKMZRj8";
my $SECRET_KEY = "Yr4eePOXAqVSyGEvd1yM3QjR1wGisjf4";

# api 地址参数
my $TOKEN_URL =  "https://openapi.baidu.com/oauth/2.0/token";
my $VOP_URL = "http://vop.baidu.com/server_api";

my $CR = "\n";

my $audio_file = shift or die 'expect *.mp3 file as argument';
# my $token = get_token() or die 'fail to get access token';
my $token = '24.b467dae656a8779822b6c4761748eb91.2592000.1548385257.282335-15270466';
my $text = speech($token, $audio_file);
print $text, "\n";

$text = decode('utf8', $text);
my @text = split(//, $text);
my $count = scalar(@text);
print "$count chars: ";
print join(' ', @text), $CR;

# 获取 Access Token 授权
sub get_token
{
	my $token_url_req = "$TOKEN_URL?grant_type=client_credentials&client_id=$API_KEY&client_secret=$SECRET_KEY";
	warn $token_url_req, "\n";
	my $ua = LWP::UserAgent->new();
	my $response = $ua->post($token_url_req);
	if ($response->is_success) {
		my $res_str = $response->decoded_content();
		warn "$res_str\n";
		my $json = JSON->new();
		my $res_json = $json->decode($res_str);
		my $token_str = $res_json->{access_token};
		return $token_str;
	}
	else {
		die $response->status_line;
	}
	return "";
}

# 请求语音识别
# 入参：token 与 音频文件
# 出参：识别结果文字
sub speech
{
	my ($token, $audio_file) = @_;

	my $content = '';
	open(my $fh, '<', $audio_file) or die "cannot open $audio_file $!";
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

	die $response->status_line unless ($response->is_success);
	my $res_str = $response->decoded_content();
	warn "$res_str\n";

	my $res_json = $json->decode($res_str);
	if ($res_json->{err_no} != 0) {
		return '';
	}

	return $res_json->{result}->[0];
}
