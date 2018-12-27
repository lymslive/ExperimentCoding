$p_person_recharge=<<EOF;
支付宝支付充值
app支付成功后，服务端会推送"obj":"order", "act":"finish"
输入：
{
	"obj":"person",
	"act":"recharge",
	"order_id":订单号（前端生成，32个字符内，保证唯一性，比如person_id+当前时间）
	"person_id":用户id,
	"rmb":充值金额, 单位：元
	"pay_type":"wechat"微信，"alipay"支付宝
	"client_type":"app"客户端, "wxa"小程序
	
	//仅当"client_type"为"wxa"时需要以下字段
	"openid":""用户端小程序openid
}
输出：
{
	"obj":"order",
	"act":"recharge",
	"status":"success"
	///微信支付 返回
	"pay_info":{
		"pay_money":3元 
		"package":""数据包
		"nonceStr":随机字符串
		"paySign":签名
		"signType":"MD5" 签名算法
		"timeStamp":时间戳
		"prepayid":"" 微信返回的支付交易会话ID
	},
	///支付宝 返回
	"token_id":""请求参数（支付宝支付）
}

EOF

sub p_person_recharge {
	return jr({status=>"failed"}) unless assert(length($gr->{order_id}), "order_id not set", "ERR_ORDER_ID_MISSING", "订单id丢失");
	return jr({status=>"failed"}) unless assert(length($gr->{person_id}), "person_id not set", "ERR_PERSON_ID_MISSING", "用户_id丢失");
	return jr({status=>"failed"}) unless assert(length($gr->{rmb}), "rmb not set", "ERR_RMB_MISSING", "充值金额未设置");
	return jr({status=>"failed"}) unless assert(length($gr->{pay_type}), "pay_type not set", "ERR_PAY_TYPE_MISSING", "支付类型丢失");
	return jr({status=>"failed"}) unless assert(length($gr->{client_type}), "client_type not set", "ERR_CLIENT_TYPE_MISSING", "客户端类型丢失");
	my @pay_types = ("wechat", "alipay"); #, "apple", "official");
	if ( !(grep {$_ eq $gr->{pay_type}} @pay_types) ) {
		return jr({status=>"failed"}) unless assert(0, "pay_type unsupported", "ERR_PAY_TYPE_INVALID", "该支付类型不支持哦");
	}
	$gr->{is_app} = "true";
	if ($gr->{client_type} eq "wxa") {#小程序支付必须传用户openid
		return jr({status=>"failed"}) unless assert(length($gr->{openid}), "openid not set", "ERR_OPENID_MISSING", "用户openid丢失");
		$gr->{is_app} = "false";
	}
	my $person = obj_read("person", $gr->{person_id}, 1);
	return jr({status=>"failed"}) unless assert($person, "person not exists", "ERR_PERSON_NOT_EXISTS", "用户信息丢失");
	
	$gr->{rmb} += 0;
	my $now_t = time();
	my $recharge = mdb()->get_collection("recharge")->find_one({order_id=>$gr->{order_id}});
	if (!$recharge) {
		$recharge->{_id} = obj_id()."_recharge";  #为了和order表区别开
		$recharge->{type} = "recharge";
		$recharge->{et} = $recharge->{ut} = $now_t;
		$recharge->{order_id} = $gr->{order_id};
		$recharge->{person_id} = $gr->{person_id};
		$recharge->{display_name} = $person->{display_name};
		$recharge->{history} = $person->{history_recharge} + 0;
		$recharge->{old_left_money} = $person->{left_money} + 0;
		$recharge->{phone} = $person->{phone};
		$recharge->{rmb} = $gr->{rmb};
		$recharge->{buy_type} = "recharge";
		$recharge->{pay_type} = $gr->{pay_type};
		$recharge->{client_type} = $gr->{client_type};
		$recharge->{status} = "create";
		$recharge->{city_code} = $person->{city_code}; #【小工三期】
		$recharge->{is_app} = $gr->{is_app};
		if (length($gr->{openid})) {
			$recharge->{openid} = $gr->{openid};
		}
	} else {
		return jr({status=>"failed"}) unless assert(0, "order exists", "ERR_ORDER_EXISTS", "订单号已存在不能修改");
	}
	my $prepay_info = {};
	my $pay_info = {};
	my $token_id = "";
	if ($gr->{pay_type} eq "wechat") {
		$prepay_info = wechat_get_prepay_id($recharge);
	} elsif ($gr->{pay_type} eq "alipay") {
		$prepay_info = alipay_get_prepay_id($recharge);
	}
	if ($gr->{pay_type} eq "wechat") {#微信支付
		if ($prepay_info->{return_code} ne "SUCCESS" || $prepay_info->{result_code} ne "SUCCESS") {
			obj_write($recharge);
			return jr({status=>"failed", wx_msg=>$prepay_info->{message}}) unless assert(0, "get prepayid failed", "ERR_GET_PREPAYID", "获取预支付订单信息失败");
		}
		$recharge->{prepay_id} = $prepay_info->{prepay_id};
		my $ret = set_wechat_paysign_params($prepay_info, $gr->{is_app}, $now_t);
		$pay_info = $ret->{pay_info};
		$pay_info->{package} = $ret->{temp}->{package};
		$pay_info->{paySign} = md5_sign($ret->{temp}, $ret->{trade_type});
		$pay_info->{pay_money} = $recharge->{rmb};
		
	} else {#支付宝
		$recharge->{prepay_id} = $prepay_info->{sign_str};
		$token_id = $prepay_info->{sign_str};
	}
	$recharge->{ut} = $now_t;
	$recharge->{status} = "prepay";
	obj_write($recharge);
	return jr({status=>"success", token_id=>$token_id, pay_info=>$pay_info});
}

$p_order_finish=<<EOF;
订单支付结束
输入：
{
	"obj":"order",
	"act":"finish",
	"out_trade_no":商户订单号,
	"pay_result":支付状态"success"表示成功，其他表示失败
	"transaction_id":订单号
}
输出：
{
	"obj":"order",
	"act":"finish",
	"status":"success"成功,"failed"失败
	"order_info":{
		
	}
}
EOF
sub p_order_finish {
	return jr({status=>"failed"}) unless assert(length($gr->{out_trade_no}), "out_trade_no not set", "ERR_TRADE_NO_MISSING", "商户订单号丢失");
	return jr({status=>"failed"}) unless assert(length($gr->{pay_result}), "pay_result not set", "ERR_PAY_RESULT_MISSING", "支付结果丢失");

	my $out_trade_no = $gr->{out_trade_no};
	if (index($out_trade_no, "_recharge") > 0) { #用户充值
		return set_recharge_finish($gr);
	}
}

sub set_recharge_finish {
	my ($gr) = @_;
	
	my $out_trade_no = $gr->{out_trade_no};
	my $recharge = obj_read("recharge", $out_trade_no, 1);
	return jr({status=>"failed"}) unless assert($recharge, "recharge not exists", "ERR_RECHARGE_NOT_EXISTS", "订单信息丢失");
	
	my $now_t = time();
	my $rmb = $recharge->{rmb} + 0;
	$recharge->{transaction_id} = $gr->{transaction_id};
	$recharge->{pay_result} = $gr->{pay_result};
	$recharge->{ut} = $now_t;
	$recharge->{pay_status} = "finish_pay";
	if ($recharge->{client_type} eq "app") {#APP支付需推送
		my $app_msg;
		$app_msg->{obj} = "order";
		$app_msg->{act} = "finish";
		$app_msg->{order_id} = $recharge->{order_id};
		$app_msg->{money} = $recharge->{rmb};
		$app_msg->{pay_result} = $gr->{pay_result};
		$app_msg->{call} = "recharge_finish";
		my $ret = sendto_pid_v2($gr->{server}, $recharge->{person_id}, $app_msg, 1); # 【小工三期】加入极光推送
	}
	if ($recharge->{pay_result} ne "success") {#支付失败
		obj_write($recharge);
		return jr({status=>"failed", order_info=>$recharge});
	}

	#支付成功
	my $person = obj_read("person", $recharge->{person_id}, 1);
	$person->{left_money} += $recharge->{rmb};
	$person->{history_recharge} += $recharge->{rmb};
	obj_write($person);
	
	obj_write($recharge);

	return jr({status=>"success", order_info=>$recharge});
}



#支付宝支付相关参数
#
# rsa_pkcs8_private：商户pkcs8格式的私钥，生成签名时使用
# ali_rsa_public_key：支付宝公钥， 验证签名时使用
#
$ALIPAY_CONFIG={ 
	appid=>'???', #合作者id
	method=>'alipay.trade.app.pay',
	charset=>'utf-8',
	sign_type=>'RSA',
	product_code=>'QUICK_MSECURITY_PAY',
	#商户私钥(原始格式)，有原始格式和pkcs8格式，一般java使用pkcs8格式，php和c#语言使用原始格式。
	rsa_private_key => 'MIIEvQIBADA???'
};

#
#my $rsa_pub = Crypt::OpenSSL::RSA->new_public_key($rsa_public_key);
#my $ciphertext = $rsa_pub->encrypt($sign_string);
#my $ciphb64 = encode_base64($ciphertext);
#注意sign_type是否需要参与组装（一般规则： mapi网关请求通常签名不需要sign_type参与，openapi网关请求通常签名需要sign_type参与，收到的支付宝异步通知请求通常验签不需要sign_type参与。具体请参见文档。） 
#
sub RSA_sign{
	my ($key, $content) = @_;
	return 0 unless $content;
	
	my $file_path = "/var/www/games/app/xgzx_ga";
	if(uc(__PACKAGE__) eq "XGZX") {
		$file_path = "/var/www/games/app/xgzx"
	}
	
	my $sign = "";
	if (!(-e "$file_path/RSA.class")) {#未编译或者是RSA.java有更新
		$sign = `cd $file_path;javac RSA.java;java -cp . RSA '$key' '$content'`;
	} else {
		my $class = (stat "$file_path/RSA.class")[9];#传文件最近一次被修改的unix时间戳
		my $java = (stat "$file_path/RSA.java")[9];
		if ($class < $java) {
			$sign = `cd $file_path;javac RSA.java;java -cp . RSA '$key' '$content'`;
		} else {
			$sign = `cd $file_path;java -cp . RSA '$key' '$content'`;
		}
	}
	chomp($sign); 
	return $sign;
}

sub rsa_sign {
	my ($params, $rsa_private_key)= @_;
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

	my $sign = RSA_sign($rsa_private_key, $sign_string);
	#$sign_string .= sprintf( '&sign=%s', $sign );
	my $ret;
	$ret->{sign} = $sign;
	$ret->{unsign} = $sign_string;
	return $ret;
}

#app_id=??
#biz_content={"timeout_express":"30m","seller_id":"","product_code":"QUICK_MSECURITY_PAY","total_amount":"0.01","subject":"1","body":"我是测试数据","out_trade_no":"IQJZSRC1YMQB5HU"}
#charset=utf-8
#format=json
#method=alipay.trade.app.pay
#notify_url=http://domain.merchant.com/payment_notify
#sign_type=RSA
#timestamp=2016-08-25 20:26:31
#version=1.0

sub alipay_get_prepay_id {
	my $order_info = $_[0];
	
	#my $person_id = $order_info->{person_id};
	my $total_amount = sprintf("%.2f", $order_info->{rmb}+0); #订单总金额，单位为元，精确到小数点后两位，取值范围[0.01,100000000]
	my $PayInfo;
	$PayInfo->{app_id} = $ALIPAY_CONFIG->{appid};
	my $body = lc(__PACKAGE__);
	$PayInfo->{biz_content} = '{"body":"'.$body.'","out_trade_no":"'.$order_info->{_id}.'", "product_code":"'.$ALIPAY_CONFIG->{product_code}.'", "subject":"'.$order_info->{order_id}.'","total_amount":"'.$total_amount.'"}';
	
	$PayInfo->{charset} = $ALIPAY_CONFIG->{charset};
	$PayInfo->{method} = $ALIPAY_CONFIG->{method};
	$PayInfo->{sign_type} = $ALIPAY_CONFIG->{sign_type};
	$PayInfo->{timestamp} = formateTime(time());
	$PayInfo->{notify_url} = $WECHAT_CONFIG->{notify_url};
	$PayInfo->{format} = "json";
	$PayInfo->{version} = "1.0";
	my $ret_sign = rsa_sign($PayInfo, $ALIPAY_CONFIG->{rsa_private_key});
	$PayInfo->{sign} = $ret_sign->{sign};
	#对所有value（biz_content作为一个value）进行url encode
	my $params_sign = {};
	foreach (keys %{$PayInfo}) {
		$params_sign->{$_} = uri_escape_utf8($PayInfo->{$_});
	}
	my $sign_string = join( '&',
		map { sprintf( '%s=%s', $_, $params_sign->{$_} ) }
		sort { $a cmp $b } keys %$params_sign );    
	my $ret;
	$ret->{sign_str} = $sign_string;
	$ret->{unsign} = $ret_sign->{unsign};
	return $ret;
}


