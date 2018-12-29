$p_system_paytype_set = <<EOF;
设定支付方式的显隐
输入：
{
	wechat: 1,
	alipay: 1,
	apple:1
}
输出：
{
	state: success, // 至少改变一个值返回成功，否则 fail
	wechat: new_value,
	alipay: new_value,
	apple:new_value
}
示例：{"obj":"system","act":"paytype_set","wechat":0,"alipay":0,"apple":1}
EOF

sub p_system_paytype_set
{
	if (not (defined $gr->{wechat} || defined $gr->{alipay} || defined $gr{apple})) {
		return jr({state => "fail"});
	}

	my $old = obj_read('system', 'paytype');
	my $wechat = $old->{wechat} || 0;
	my $alipay = $old->{alipay} || 0;
	my $apple = $old->{apple} || 0;
	if (defined $gr->{wechat}) {
		$wechat = 0 + $gr->{wechat};
	}
	if (defined $gr->{alipay}) {
		$alipay = 0 + $gr->{alipay};
	}
	if (defined $gr->{apple}) {
		$apple = 0 + $gr->{apple};
	}

	my $ref = {
		_id => "paytype",
		type => "system",
		wechat => $wechat,
		alipay => $alipay,
		apple => $apple,
	};
	obj_write($ref);

	return jr({state => "success",
			wechat => $wechat,
			alipay => $alipay,
			apple => $apple,
		});
}
