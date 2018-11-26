
int build_sql(stOrder, bIgnore)
{
#undef SQL_SET
#define SQL_SET(v,f) if(!SqlBuild::IsZero(v) || !bIgnore) sqlSet += SqlBuild::set(v, f)
	SQL_SET(stOrder.F_order_id, "F_order_id");
	SQL_SET(stOrder.F_mch, "F_mch_id");
	SQL_SET(stOrder.F_channel_id, "F_channel_id");
}

int build_sql(stOrder, bSkip)
{
#undef SQL_SET
#define SQL_SET(v,f) if(!SqlBuild::IsZero(v) || !bSkip) sqlSet += SqlBuild::set(v, f)
	SQL_SET(stOrder.F_order_id, "F_order_id");
	SQL_SET(stOrder.F_mch, "F_mch_id");
	SQL_SET(stOrder.F_channel_id, "F_channel_id");
}
