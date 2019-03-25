#include "sqloper.h"

namespace Json {
namespace Sql {

#define EINT int

EINT doInsert(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns, int affect/* = 1*/)
{
	String strSql = Insert(table, columns);
	int affected = conn->update(strSql);
	return (affected == affect) ? 0 : -1;
}

EINT doReplace(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns)
{
	String strSql = Replace(table, columns);
	int affected = conn->update(strSql);
	return (affected >= 1) ? 0 : -1;
}

EINT doUpdate(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns, const Json::Value& keys, int affect)
{
	String strSql = Update(table, columns, keys);
	int affected = conn->update(strSql);
	if (affect > 0)
	{
		return (affected == affect) ? 0 : -1;
	}
	return 0;
}

EINT doUpdate(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns, const String& where, int affect)
{
	String strSql = Update(table, columns, Json::Value());
	strSql += " AND ";
	strSql += where;
	int affected = conn->update(strSql);
	if (affect > 0)
	{
		return (affected == affect) ? 0 : -1;
	}
	return 0;
}

static 
EINT SelectSingle(MysqlConnScopedPtr& conn, const String& strSql, Json::Value& columns)
{
	ScopedPtr<mysql::ResultSet> rs;
	rs.reset(conn->query(strSql));
	if (!rs || !rs->next())
	{
		return -1;
	}

	Json::Value::Members vecMember = columns.getMemberNames();
	int iSize = vecMember.size();
	String key;
	for (int i = 0; i < iSize; ++i)
	{
		key = vecMember[i];
		if (columns[key].isInt())
		{
			columns[key] = rs->getInt32(i);
		}
		else
		{
			columns[key] = rs->getString(i);
		}
	}

	return 0;
}

EINT doSelect(MysqlConnScopedPtr& conn, const String& table, Json::Value& columns, const Json::Value& keys)
{
	String strSql = Select(table, columns, keys);
	return SelectSingle(conn, strSql, columns);
}

EINT doSelect(MysqlConnScopedPtr& conn, const String& table, Json::Value& columns, const String& where)
{
	String strSql = Select(table, columns, Json::Value());
	strSql += " AND ";
	strSql += where;
	return SelectSingle(conn, strSql, columns);
}

static 
int SelectArray(MysqlConnScopedPtr& conn, const String& strSql, const Json::Value& columns, Json::Value& result)
{
	ScopedPtr<mysql::ResultSet> rs;
	rs.reset(conn->query(strSql));
	if (!rs)
	{
		return 0;
	}

	Json::Value::Members vecMember = columns.getMemberNames();
	int iSize = vecMember.size();

	result = Json::Value(Json::ValueType::arrayValue);
	String key;
	while (rs->next())
	{
		Json::Value obj;
		for (int i = 0; i < iSize; ++i)
		{
			key = vecMember[i];
			if (columns[key].isInt())
			{
				obj[key] = rs->getInt32(i);
			}
			else
			{
				obj[key] = rs->getString(i);
			}
		}
		result.append(obj);
	}

	return result.size();
}

int doSelect(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns, const Json::Value& keys, Json::Value& result)
{
	String strSql = Select(table, columns, keys);
	return SelectArray(conn, strSql, columns, result);
}

int doSelect(MysqlConnScopedPtr& conn, const String& table, const Json::Value& columns, const String& where, Json::Value& result)
{
	String strSql = Select(table, columns, Json::Value());
	strSql += " AND ";
	strSql += where;
	return SelectArray(conn, strSql, columns, result);
}


} // namespace Sql
} // namespace Json
