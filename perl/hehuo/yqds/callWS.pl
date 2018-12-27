#!/opt/perl/bin/perl
# 
# 

use Mojo::UserAgent;
use JSON;
use utf8;
use Encode;
use Data::Dumper;
use Digest::MD5 qw/md5_hex/;

binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');


# flush after every write
$| = 1;

$json = JSON->new;
$WS_URLS = {
	yqds => "ws://47.104.209.172:51717/yqds",
	yqds_ga => "ws://47.104.209.172:80/yqds_ga"
};

my ($RSP) = @ARGV;

open Log,">>/tmp/callWS.log";

print Log $RSP."\n";

$RSP = Encode::decode("utf8", $RSP);
#print Log "decode_utf8: ".$RSP."\n";

my $rsp_json = $json->decode($RSP);
$CALL_TYPE = $rsp_json->{obj}."_".$rsp_json->{act};
$WS_SERVER = $WS_URLS->{$rsp_json->{proj}};

print Log Dumper($rsp_json)."\n";
close Log;

my $ua = Mojo::UserAgent->new;
$resp_len = 0;

# Non-blocking WebSocket connection sending and receiving JSON messages
$ua->websocket($WS_SERVER => sub {
  my ($ua, $tx) = @_; #所有参数
  
  die "WebSocket handshake failed!\nWS_SERVER: $WS_SERVER\n" and exit unless $tx->is_websocket;
  
  $tx->on(finish => sub {
    my ($tx, $code, $reason) = @_;
    die "WebSocket closed with status $code:$reason\nWS_SERVER: $WS_SERVER\n"; #表示终止脚本运行，并显示出die后面的双引号里面的内容
  });
  
  $tx->on(message => sub {
    my ($tx, $msg) = @_;
    
    # keep receiving until we have all the responded data
    if ($resp_len == 0) {
		($resp_len) = ($msg =~ /^(\d+)$/m); #=~是正则匹配运算符，当左操作数符合右操作数的正则表达式时返回非false值
		$msg =~ s/\d+\n//;
		$resp_buf = $msg;
    } else {
        $resp_buf .= $msg;
    }
    $resp_len -= length(Encode::encode_utf8($msg)); 
    return if ($resp_len) > 0;
    # set the globals of the response
    chomp $resp_buf;
    if ($resp_buf =~ /^\{/s && $resp_buf =~ /\}$/s) { 
        #通用脚本，返回等待解析的字符串即可,由调用者自己进行解析
        print $resp_buf."\n"; 
		exit;
    } else {
        die "Fatal, illformed json string!!\n\n";
    }

  });
  $resp_len = 0;
  
  if ($CALL_TYPE eq "order_finish") {
  	   $tx->send($RSP."\n");
  }
  
  if ($CALL_TYPE eq "classGrouping_serverRandom") {
  	   $tx->send($RSP."\n");
  }
  
  #if ($CALL_TYPE eq "importStudent_add") {
  #	   $tx->send($RSP."\n");
  #}
});

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

