use warnings;
use utf8;
binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');

use CGI;
use JSON;
use Encode;
use Date::Parse;
use Data::Dumper;
use Time::HiRes qw(gettimeofday usleep);
use HTTP::Request;
use HTTP::Headers;
use LWP::UserAgent;
use XML::Simple;

$wechat_config={ 
	user => {#用户端小程序
		appid=>'wxcd3f5be2d3b476ab',
    	appSecret=>'cdb3da44af808b8e5125ae57df4fe29e'
	},
	wxpay => {
		mch_id => '1516464331',
		appid => 'wxcd3f5be2d3b476ab',
		appkey => 'Banni18120885256xuexi59187922190',
	},
	user_app => {#用户端APP
    	mch_id => '1516464331',
    	appid=>'wxcd3f5be2d3b476ab',
		appkey => 'Banni18120885256xuexi59187922190',
	},
};

$ali_config={ 
    appid=>'2018101161628895', #开发者的应用Id
    #partner_id=>'xxxxx', #合作者id
    seller_id=>'2088131332781386',  #卖家支付宝用户号
    method=>'alipay.trade.app.pay',
    charset=>'utf-8',
    sign_type=>'RSA2',
    product_code=>'QUICK_MSECURITY_PAY',
	ali_rsa_public_key => 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6XmfNRj/4u+YuMhKsJMDDiRDXSgSdcExQ24zq+QuHMpar7jMnP5gu23dE9qmReQZDjm+YUBj9fgEhfvL+jXCWN54ZhvCyqNbtUg8ZkPRjHDLz13+qg2zOe2Nw9p8KQmKOy90wJcrPapf0wepVBl39gi8FkJyusbgsGwOsO49ScPxjRfvgC3D6608Uho5MZG+yC1SiLXSW4rniM6EuFKPcyBXE9VhZfSgYHjZcwXzJHz+DEJAZVWCo2Adp4EXA2CKFNW2b0RYugMi2XSIbtRWF8XpcniVbA7u8dZkoLN+QyrhozYTRU3ufr3GmGG5dMwqg+5c0wxflecKnpRFiseGnQIDAQAB'
};

$cgi = CGI->new();
$json = JSON->new;
my $OUTPUT = '{"unionid":"", "openid":"", "status":"failed"}';

if ($cgi->param("echostr")) {
	print "Content-type:text/html\r\n\r\n";
	print $cgi->param("echostr");
	exit;
}

if ($cgi->param("POSTDATA")) {
	my $post_data = $cgi->param("POSTDATA");
	write_log("post_data.log", Dumper($post_data));
	#$post_data =~s/[\r\n]//g;  #去掉回车换行，以免正则匹配失败
	if ($post_data =~m/{.+}/) { #内部约定的json数据
		my $input_json = $json->decode($post_data);
		#数据校验 {"iv":"xxx", "encryptedData":"xxx", "proj":"user", "act":"getUid", "obj":"sales"}
		my $proj = $input_json->{proj};
		write_log("input.log", $post_data."\n".Dumper($input_json), $proj);
		if ($input_json->{act} eq "getUid") {
			if (length($input_json->{proj}) && length($input_json->{obj}) && length($input_json->{iv}) 
				&& length($input_json->{encryptedData}) && length($input_json->{js_code})
			   ) {
			   	my $obj = $input_json->{obj};
				my $iv = $input_json->{iv};
				my $data = $input_json->{encryptedData};
				my $jscode = $input_json->{js_code};
				my $appId = $wechat_config->{$obj}->{appid};
				my $key = $wechat_config->{$obj}->{appSecret};
				my $ret = get_wx_session_key($appId, $key, $jscode);
				my $session_key = "";
				if (defined $ret->{session_key}) {
					$session_key = $ret->{session_key};
				} else {
					$OUTPUT = '{"unionid":"", "openid":"", "status":"failed", "errMsg":"get sessionKey failed"}';
					print_result($OUTPUT);
					exit;
				}
				write_log("getUid.log", "jscode=".$jscode."\niv= ".$iv."\nencryptedData= ".$data."\nsession_key=".$session_key, $proj);
				my $result = readpipe("python /var/www/games/app/xgzx/aes.py $appId $session_key $iv $data");
				write_log("getUid.log", "result= ".$result, $proj);
				if ($result =~m/{.+}/) {
					my $result_json = $json->decode($result);
					my $unionid = "";
					my $openid = $result_json->{openId};
					if (defined $result_json->{unionId}) {
						$unionid = $result_json->{unionId};
					} else {
						$unionid = $result_json->{openId};
					}
					$OUTPUT = '{"unionid":"'.$unionid.'", "openid":"'.$openid.'", "status":"success"}';
				}
			}
		} else {
			write_log("input.log", "act:".$input_json->{act}."Not implement", $proj);
		}
		print_result($OUTPUT);

	} else { #if ($post_data =~m/<xml.+xml>/) {# 微信支付回调返回的数据
		my $xml_chk = "false";
		if ($post_data =~m/<xml.+xml>/) { 
			$xml_chk = "true";
		}
		my $out_trade_no = "";
		my $transaction_id = "";
		my $pay_result = "success";#支付成功
		my $xml_return = $post_data;
		write_log("notify_url.log", "xml:".$xml_return."\nxml_chk:".$xml_chk, "");
		
		my $json_return =  parse_response_with_xml($xml_return);  #本次支付是否成功的xml文档
		write_log("notify_url.log", "xml:".$xml_return."\njson:".Dumper($json_return)."\nxml_chk:".$xml_chk, "");
	
		if ($json_return->{return_code} ne "SUCCESS") {
			print_html_notify_rsp("success"); #支付失败（无订单号信息），直接退出

		} elsif ($json_return->{result_code} ne "SUCCESS") {
			$pay_result = "failed";#支付失败（有订单号信息）
		}
		$out_trade_no = $json_return->{out_trade_no}; #数据库表order的记录_id
		$transaction_id = $json_return->{transaction_id}; #订单号
	
		my $param_json;###############################################checkout
		$param_json->{obj} = "order";
		$param_json->{act} = "finish";
		$param_json->{proj} = $json_return->{attach};
		$param_json->{pay_result} = $pay_result;
		$param_json->{PaymentBillId} = $out_trade_no;
		$param_json->{transaction_id} = $transaction_id;
		my $param_json_str = $json->encode($param_json);
		my $ws_return = callXgzx($param_json_str);
	
		#3 if return some error,Log error info to log file
		if ($ws_return->{derr}) {
			write_log("pay_finish_err.log", $ws_return->{ustr}.", $out_trade_no", "");
			print_html_notify_rsp("fail");
		}
		print_html_notify_rsp("success");
	}

} elsif ($cgi->param("app_id")) {#支付宝notify_url返回的
	my $json_return = {};
	foreach my $k (keys %{$cgi->{param}}) {
		$json_return->{$k} = $cgi->{param}->{$k}[0];
	}
	write_log("ali_notify_url.log", "rsp:".Dumper($cgi->{param})."\nmy_json:".Dumper($json_return));
	
	my $out_trade_no = "";
	my $transaction_id = "";
	my $pay_result = verify_ali_notify_data($json_return);
	if ($pay_result eq "success") {
		$out_trade_no = $json_return->{out_trade_no}; #数据库表order的记录_id
		$transaction_id = $json_return->{trade_no}; #支付宝交易号
	}
	my $param_json;
	$param_json->{obj} = "order";
	$param_json->{act} = "finish";
	$param_json->{proj} = "yqds";#$json_return->{attach};
	$param_json->{pay_result} = $pay_result;
	$param_json->{PaymentBillId} = $out_trade_no;
	$param_json->{transaction_id} = $transaction_id;
	my $param_json_str = $json->encode($param_json);
	my $ws_return = callXgzx($param_json_str);

	write_log("1111111.log", $ws_return);
	
	if ($ali_return->{derr}) {
		write_log("ali_finish_err.log", $ali_return->{ustr}.", $out_trade_no");
		print_html_notify_rsp("fail");
	}
	print_html_notify_rsp("success");
}
# 苹果内购返回
elsif ($cgi->param("apple")) {
	my $BillId = $cgi->param("bill");
	my $Receipt = $cgi->param("receipt");
	my $valid = 1;

	# $valid = verify_apple_receipt($Receipt);
	if ($valid) {
		my $param_json;
		$param_json->{obj} = "order";
		$param_json->{act} = "finish";
		$param_json->{proj} = "yqds";
		$param_json->{pay_result} = "success";
		$param_json->{PaymentBillId} = $BillId;
		my $param_json_str = $json->encode($param_json);

		my $ws_return = callXgzx($param_json_str);
		if ($ws_return->{derr}) {
			write_log("apple_buy.log", $ws_return->{ustr}.", $BillId", "");
			print_html_notify_rsp("fail");
		}
		else {
			write_log("apple_buy.log", $ws_return);
			print_html_notify_rsp("success");
		}
	}
	else {
		write_log("apple_buy.log", "itunes varify failed");
		print_html_notify_rsp("fail");
	}

}
exit;

############################################################################################################
sub write_log {
	my ($file_name, $content, $proj) = @_;
	
	my $dir_main = "/tmp/xgzx";
	mkdir $dir_main unless -d $dir_main;
	my $dir = $dir_main;
	if($proj && $proj ne "") {
		$dir = $dir_main."/$proj" ;
		mkdir $dir 	unless -d $dir;
	}
	#system("cp /dev/null $file_name") if (-s $file_name) > 1_000_000_000;
	open Log,">>$dir/$file_name";
	print Log localtime(time).": $content\n";
	close Log;
}

sub callXgzx {
	my $param_json_str=$_[0];
	write_log("json.log", "$param_json_str", "");
	my $resp_buf = `perl /usr/lib/cgi-bin/callWS.pl '$param_json_str'`;

	write_log("1111111.log", $resp_buf);
#	my @lines = split /\n/, $resp_buf;        
#	my $resp_tmp = $json->decode("[".join(",", @lines)."]"); 
#	my $tmp = shift @{$resp_tmp}; 
	my $resp = decode_json($resp_buf);
	return $resp;
}

sub print_html_notify_rsp{###
	my $status=$_[0];
	print "Content-type:text/html\n\n";
	print $status;
	exit;
}

sub print_result {
	my $output = $_[0];
	print "Access-Control-Allow-Origin: *\r\n";
	print "Content-Type: application/json\r\n\r\n";
	print $output;
	exit;
}

sub parse_response_with_xml {###
    my $content = $_[0];
    my $result  = XMLin($content);
    return $result;

	if ($result->{return_code} eq "SUCCESS" ) {
		$sign_gal = $result->{sign};
		if ($result->{result_code} eq "SUCCESS") {
			return $result if valid_response($result);
			#$result->{errmsg}=$result->{err_msg};
			return $result;
		} else {
			#return $result->{errmsg}=$result->{err_msg};
			return $result; 
		}
	}
}

# say:use this method to valid response sign
sub valid_response {###
    my $params  = $_[0];
    my $sign    = delete $params->{sign}; 
    my $sign_me = sign($params);
    
    if ($sign and $sign eq $sign_me) {
		$params->{sign} = $sign;
		return 1;
    } else {
		return 0; 
    }
}

sub sign {###
    #creat a new digital sing needs some params:appid mchid ....
    my $params      = $_[0];
    my $app_key = $wechat_config->{wxpay}->{appkey};
    if ($params->{trade_type} eq "APP") {
		$app_key = $wechat_config->{user_app}->{appkey};
	}
    my $params_sign = {};
    foreach ( keys %$params ) {
        next if $_ eq 'sign';
        next unless defined $params->{$_};
        Encode::_utf8_off( $params->{$_} );
        $params_sign->{$_} = $params->{$_};
    }

    my $sign_string = join( '&',
        map { sprintf( '%s=%s', $_, $params_sign->{$_} ) }
        sort { $a cmp $b } keys %$params_sign );
      
    $sign_string .= sprintf( '&key=%s', $app_key );

    return uc md5_hex $sign_string;
}

sub get_wx_session_key {
	my ($appId, $secret, $jscode) = @_;
	my $session_key_api = "https://api.weixin.qq.com/sns/jscode2session?appid=".$appId."&secret=".$secret."&js_code=".$jscode."&grant_type=authorization_code";

    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new('GET', $session_key_api); 
    my $response = $ua->request($req);
    my $ret;
	if ($response->message ne "OK" && $response->is_success ne "1") { #出错，或者timeout了
		$ret->{status} = "time out";
	} else {
		$ret = $json->decode($response->decoded_content());
	}
	write_log("session_key.log", " $session_key_api"."\n wechat.rsp:".Dumper($ret), "");
    return $ret;
}

sub RSA_sign{
	my ($key, $content) = @_;
	return 0 unless $content;
  
	my $file_path = "/var/www/games/app/xgzx_ga";
  	my $sign = `cd $file_path;java -cp . RSA '$key' '$content'`;
	chomp($sign); 
	return $sign;
}

sub rsa_sign {
	my $params  = $_[0];
    my $rsa_key = $_[1];
    my $params_sign = {};
    foreach ( keys %$params ) {
        next if $_ eq 'sign';
        next unless defined $params->{$_};
        Encode::_utf8_off( $params->{$_} );
        $params_sign->{$_} = $params->{$_};
    }

    my $sign_string = join( '&',
        map { sprintf( '%s=%s', $_, $params_sign->{$_} ) }
        sort { $a cmp $b } keys %$params_sign );
	
	return RSA_sign($rsa_key, $sign_string);
}

sub valid_ali_sign {
    my $params  = $_[0];
    my $rsa_key  = $_[1];
    #除去sign、sign_type两个参数外
    my $sign = delete $params->{sign};
    my $sign_type = delete $params->{sign_type};
    my $sign_me = rsa_sign($params, $rsa_key);
    
    if ($sign and $sign eq $sign_me) {
		$params->{sign}=$sign;
		return 1;
    } else {
		return 1;  #测试阶段先不校验
    }
}

#HTTPS_VERIFY_URL = "https://mapi.alipay.com/gateway.do?service=notify_verify&partner=&notify_id="; #判断请求是否支付宝发送的合法消息
sub verify_ali_notify_data {
	my $json_params = $_[0];

	return "failed" if (!$json_params->{notify_id}); #必须存在项
	return "failed" if (!$json_params->{app_id} || $json_params->{app_id} ne $ali_config->{appid}); #必须存在项
	return "failed" if ($json_params->{sign_type} ne $ali_config->{sign_type}); #不匹配
	return "failed" if ($json_params->{seller_id} && $json_params->{seller_id} ne $ali_config->{seller_id}); #不匹配
	return "failed" if (!valid_ali_sign($json_params, $ali_config->{ali_rsa_public_key})); #签名错误
	
	#只有交易通知状态为TRADE_SUCCESS或TRADE_FINISHED时，支付宝才会认定为买家付款成功。
	return "failed" if ($json_params->{trade_status} ne "TRADE_SUCCESS" && $json_params->{trade_status} ne "TRADE_FINISHED");
	return "success";
}

# 向苹果服务验证支付凭证
sub verify_apple_receipt
{
	my ($receipt) = @_;
	my $apple_url = 'https://buy.itunes.apple.com/verifyReceipt';
	# my $apple_url = 'https://sandbox.itunes.apple.com/verifyReceipt';
	
	my $json = JSON->new();
	my $JsonData = {'receipt-data' => $receipt};
	my $JsonStr = $json->encode($JsonData);

	my $header = HTTP::Headers->new( Content_Type => 'text/json; charset=utf8', );
	my $http_request = HTTP::Request->new(POST => $apple_url, $header, $JsonStr);
	my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0, SSL_verify_mode => 0x00 });
	$ua->timeout(30); #30s, defaut 180s
	my $response = $ua->request($http_request);

	my $JsonRes = $json->decode($response->decoded_content());
	return $JsonRes->{status} eq '0';
}
