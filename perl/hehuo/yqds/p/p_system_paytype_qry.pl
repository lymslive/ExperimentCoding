$p_system_paytype_qry = <<EOF;
查询支付方式的显隐
输入：无
输出：每种支付方式的显隐 1/0
{
	wechat: 1/0,
	alipay: 1/0,
	apple: 1/0
}
示例：{"obj":"system","act":"paytype_qry"}
EOF

sub p_system_paytype_qry
{
	my $old = obj_read('system', 'paytype');
	return jr({state => 'fail'}) unless $old;

	my $wechat = $old->{wechat} || 0;
	my $alipay = $old->{alipay} || 0;
	my $apple = $old->{apple} || 0;

	return jr({state => "success",
			wechat => $wechat,
			alipay => $alipay,
			apple => $apple,
		});
}
