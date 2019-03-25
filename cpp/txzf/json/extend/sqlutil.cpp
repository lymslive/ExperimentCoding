#include "sqlutil.h"
#include <strings.h>

namespace Json {
namespace Sql {
// static 辅助函数

// 将 json 字符串或数字转为 sql 字符串，直接采用 json 单引号转义
// 非字符串或数字时返回错误
EINT SqlString(const Json::Value& val, String& outStr)
{
	if (val.isInt())
	{
		outStr = val.toString();
	}
	else if (val.isString())
	{
		outStr = String("'") + val.asString() + "'";
	}
	else
	{
		return -1;
	}
	return 0;
}

// 连接 Json 对象键值对：{prefix}key1=val1{midfix}key2=val2{midfix}...{suffix}
// 连接符与前后缀一般用简单字面字符串
// 返回分隔符串
String JoinValue(const Json::Value& columns, const char* prefix, const char* midfix, const char* suffix = NULL)
{
	String strSql;
	if (prefix)
	{
		strSql = prefix;
	}

	Json::Value::Members vecMember = columns.getMemberNames();
	int iSize = vecMember.size();
	String key, val, sql;
	for (int i = 0; i < iSize; ++i)
	{
		key = vecMember[i];
		// val = columns[key].toString();
		EINT iRet = SqlString(columns[key], val);
		if (iRet != 0)
		{
			continue;
		}
		sql = key + "=" + val;
		if (i < iSize - 1 && midfix)
		{
			sql += midfix;
		}
		strSql += sql;
	}

	if (suffix)
	{
		strSql += suffix;
	}
	return strSql;
}

// 只连接字段名：{prefix}key1{midfix}key2{midfix}...{suffix}
String JoinKeys(const Json::Value& columns, const char* prefix, const char* midfix, const char* suffix = NULL)
{
	String strSql = prefix;
	if (prefix)
	{
		strSql = prefix;
	}

	Json::Value::Members vecMember = columns.getMemberNames();
	int iSize = vecMember.size();
	String sql;
	for (int i = 0; i < iSize; ++i)
	{
		sql = vecMember[i];
		if (i < iSize - 1 && midfix)
		{
			sql += midfix;
		}
		strSql += sql;
	}

	if (suffix)
	{
		strSql += suffix;
	}
	return strSql;
}

// public 接口函数实现
String Insert(const String& table, const Json::Value& columns)
{
	if (false == columns.isObject())
	{
		return "";
	}
	String strSql = "INSERT INTO " + table;
	strSql += JoinValue(columns, " SET ", ", ");
	return strSql;
}

String Replace(const String& table, const Json::Value& columns)
{
	if (false == columns.isObject())
	{
		return "";
	}
	String strSql = "REPLACE INTO " + table;
	strSql += JoinValue(columns, " SET ", ", ");
	return strSql;
}

String Update(const String& table, const Json::Value& columns, const Json::Value& keys)
{
	if (false == columns.isObject())
	{
		return "";
	}
	String strSql = "UPDATE " + table;
	strSql += JoinValue(columns, " SET ", ", ");
	if (keys.isObject())
	{
		strSql += JoinValue(keys, " WHERE ", " AND ");
	}
	else
	{
		strSql += " WHERE 1=1";
	}

	return strSql;
}

String Select(const String& table, const Json::Value& columns, const Json::Value& keys)
{
	if (false == columns.isObject())
	{
		return "";
	}
	String strSql = "SELECT";
	strSql += JoinKeys(columns, " ", ", ");
	strSql += " FROM " + table;
	if (keys.isObject())
	{
		strSql += JoinValue(keys, " WHERE ", " AND ");
	}
	else
	{
		strSql += " WHERE 1=1";
	}

	return strSql;
}

String Where(const Json::Value& columns, const char* compare/* = NULL*/)
{
	if (false == columns.isObject())
	{
		return "";
	}

	// add an addition space around compare
	if (!compare)
	{
		compare = "=";
	}
	String cmp(" ");
	cmp += compare;
	cmp += " ";

	Json::Value::Members vecMember = columns.getMemberNames();
	int iSize = vecMember.size();
	String key, val, sql;
	for (int i = 0; i < iSize; ++i)
	{
		key = vecMember[i];
		// val = columns[key].toString();
		EINT iRet = SqlString(columns[key], val);
		if (iRet != 0)
		{
			continue;
		}

		sql += " AND " + key + cmp + val;
	}

	return sql;
}


} // namespace Sql
} // namespace Json
