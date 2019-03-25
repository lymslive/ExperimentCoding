#include "table.h"
#include <stdlib.h>

namespace Json {
namespace Sql {

Json::Value& CRecord::InvalidField()
{
	static Json::Value jNullStatic;
	return jNullStatic;
}

Json::Value& CRecord::operator[](const String& key)
{
	if (!isField(key))
	{
		LOG_ERR("InvalidField[%s]", key.c_str());
		return InvalidField();
	}
	return m_jRecord[key];
}

const Json::Value& CRecord::operator[](const String& key) const
{
	if (!isField(key))
	{
		LOG_ERR("InvalidField[%s]", key.c_str());
		return InvalidField();
	}
	return m_jRecord[key];
}

bool CRecord::isField(const String& sFieldName) const
{
	return m_pTable && m_pTable->HasField(sFieldName);
}

EINT CRecord::Load(MysqlConnScopedPtr& conn)
{
	ASSERT_RET(m_pTableMgr && m_pTable, -1);

	// Valify();
	Json::Value keys;
	for (auto it = m_pTable->m_vecKey.begin(); it != m_pTable->m_vecKey.end(); ++it)
	{
		if (false == m_jRecord.isMember(*it))
		{
			return -1;
		}
		keys[*it] = m_jRecord[*it];
	}

	String sTableName = m_pTableMgr->FullName(m_pTable->m_sTableName);
	if (m_pTable->m_bFraction)
	{
		sTableName += Fraction();
	}
	EINT iRet = doSelect(conn, sTableName, m_jRecord, keys);
	ASSERT_RET(iRet == 0, iRet);

	return 0;
}

EINT CRecord::Load(MysqlConnScopedPtr& conn, const Json::Value& jWhere)
{
	ASSERT_RET(m_pTableMgr && m_pTable, -1);
	String sTableName = m_pTableMgr->FullName(m_pTable->m_sTableName);
	if (m_pTable->m_bFraction)
	{
		sTableName += GuessFraction(jWhere);
	}
	EINT iRet = doSelect(conn, sTableName, m_jRecord, jWhere);
	ASSERT_RET(iRet == 0, iRet);
	return 0;
}

EINT CRecord::Save(MysqlConnScopedPtr& conn)
{
	ASSERT_RET(m_pTableMgr && m_pTable, -1);

	// Valify();
	Json::Value keys;
	for (auto it = m_pTable->m_vecKey.begin(); it != m_pTable->m_vecKey.end(); ++it)
	{
		if (false == m_jRecord.isMember(*it))
		{
			return -1;
		}
		keys[*it] = m_jRecord[*it];
	}

	String sTableName = m_pTableMgr->FullName(m_pTable->m_sTableName);
	if (m_pTable->m_bFraction)
	{
		sTableName += Fraction();
	}
	EINT iRet = doUpdate(conn, sTableName, m_jRecord, keys);
	ASSERT_RET(iRet == 0, iRet);

	return 0;
}

EINT CRecord::Save(MysqlConnScopedPtr& conn, const Json::Value& jWhere)
{
	ASSERT_RET(m_pTableMgr && m_pTable, -1);
	String sTableName = m_pTableMgr->FullName(m_pTable->m_sTableName);
	if (m_pTable->m_bFraction)
	{
		sTableName += GuessFraction(jWhere);
	}
	EINT iRet = doUpdate(conn, sTableName, m_jRecord, jWhere);
	ASSERT_RET(iRet == 0, iRet);
	return 0;
}

EINT CRecord::SaveNew(MysqlConnScopedPtr& conn)
{
	ASSERT_RET(m_pTableMgr && m_pTable, -1);

	// Valify();
	String sTableName = m_pTableMgr->FullName(m_pTable->m_sTableName);
	if (m_pTable->m_bFraction)
	{
		sTableName += Fraction();
	}
	EINT iRet = doInsert(conn, sTableName, m_jRecord);
	ASSERT_RET(iRet == 0, iRet);

	return 0;
}

String CRecord::Fraction()
{
	ASSERT_RET(m_pTable, "");
	if (false == m_sFraction.empty())
	{
		return m_sFraction;
	}
	String key = m_pTable->m_vecKey[0];
	String val = m_jRecord[key].asString();
	if (val.size() < 2)
	{
		return "";
	}
	return "_" + val.substr(val.size()-2);
}

String CRecord::GuessFraction(const Json::Value& jWhere)
{
	if (false == m_sFraction.empty())
	{
		return m_sFraction;
	}
	Json::Value::Members vecMember = jWhere.getMemberNames();
	ASSERT_RET(vecMember.size() > 0, "");
	String key = vecMember[0];
	ASSERT_RET(jWhere[key].isString(), "");
	String val = jWhere[key].asString();
	ASSERT_RET(val.size() >= 2, "");
	return "_" + val.substr(val.size()-2);
}

int CRecord::Valify()
{
	int iRemoved = 0;
	Json::Value::Members vecMember = m_jRecord.getMemberNames();
	for (auto it = vecMember.begin(); it < vecMember.end(); ++it)
	{
		if (!m_pTable->HasField(*it))
		{
			m_jRecord.removeMember(*it);
			++iRemoved;
		}
	}
	return iRemoved;
}

CRecord& CRecord::Mark(const String& sFieldName)
{
	ASSERT_RET(m_pTableMgr && m_pTable, *this);
	// ASSERT_RET(m_pTable->HasField(sFieldName), *this);
	if (false == m_pTable->HasField(sFieldName))
	{
		LOG_ERR("invalid field[%s]", sFieldName.c_str());
		return *this;
	}

	if (m_jRecord.isMember(sFieldName))
	{
		return *this;
	}

	Json::ValueType& val = m_pTable->m_mapField[sFieldName];
	if (val == Json::ValueType::intValue || val == Json::ValueType::uintValue)
	{
		m_jRecord[sFieldName] = 0;
	}
	else
	{
		m_jRecord[sFieldName] = "";
	}
	// LOG_ERR("mark field: [%s]\n", sFieldName.c_str());
	return *this;
}

CRecord& CRecord::Mask(const String& sFieldName)
{
	m_jRecord.removeMember(sFieldName);
	return *this;
}

CRecord& CRecord::MarkAll()
{
	ASSERT_RET(m_pTableMgr && m_pTable, *this);

	for (auto it = m_pTable->m_mapField.begin(); it != m_pTable->m_mapField.end(); ++it)
	{
		const String& key = it->first;
		Json::ValueType& val = it->second;
		if (val == Json::ValueType::intValue || val == Json::ValueType::uintValue)
		{
			m_jRecord[key] = 0;
		}
		else
		{
			m_jRecord[key] = "";
		}
	}
	return *this;
}

CRecord& CRecord::SetFraction(const String& sFraction)
{
	if (false == sFraction.empty())
	{
		m_sFraction = sFraction;
	}
	return *this;
}

String CRecord::StrField(const String& sFieldName)
{
	if (false == m_jRecord.isMember(sFieldName))
	{
		return "";
	}
	if (m_jRecord[sFieldName].isString())
	{
		return m_jRecord[sFieldName].asString();
	}
	return m_jRecord[sFieldName].toString();
}

int CRecord::IntField(const String& sFieldName)
{
	if (false == m_jRecord.isMember(sFieldName))
	{
		return 0;
	}
	if (m_jRecord[sFieldName].isInt())
	{
		return m_jRecord[sFieldName].asInt();
	}
	else if (m_jRecord[sFieldName].isString())
	{
		return atoi(m_jRecord[sFieldName].asString().c_str());
	}
	return 0;
}


CRecord CTableMgr::Record(const String& sTableName)
{
	CTable* pTable = GetTable(sTableName);
	CRecord objRecord(this, pTable);
	objRecord.MarkAll();
	return objRecord;
}

CRecord CTableMgr::Record(const String& sTableName, const String& sFraction)
{
	CTable* pTable = GetTable(sTableName);
	CRecord objRecord(this, pTable);
	objRecord.MarkAll();
	if (false == sFraction.empty())
	{
		objRecord.SetFraction(sFraction);
	}
	return objRecord;
}

CRecord CTableMgr::EmptyRecord(const String& sTableName)
{
	CTable* pTable = GetTable(sTableName);
	CRecord objRecord(this, pTable);
	return objRecord;
}

CRecord CTableMgr::EmptyRecord(const String& sTableName, const String& sFraction)
{
	CTable* pTable = GetTable(sTableName);
	CRecord objRecord(this, pTable);
	if (false == sFraction.empty())
	{
		objRecord.SetFraction(sFraction);
	}
	return objRecord;
}

EINT CTableMgr::AddTable(MysqlConnScopedPtr& conn, const String& sTableName, bool bFraction/* = false*/)
{
	CTable objTable(sTableName, bFraction);
	EINT iRet = QueryTable(conn, objTable);
	ASSERT_RET(iRet == 0, iRet);

	m_mapTable.insert(std::make_pair(sTableName, objTable));
	return 0;
}

CTable* CTableMgr::GetTable(const String& sTableName)
{
	if (m_mapTable.count(sTableName) < 1)
	{
		return NULL;
	}

	CTable* pTable = &m_mapTable[sTableName];

	return pTable;
}

// 查询表信息，构建 CTable 对象
EINT CTableMgr::QueryTable(MysqlConnScopedPtr& conn, CTable& objTable)
{
	String strSql = "select COLUMN_NAME, DATA_TYPE, COLUMN_KEY from INFORMATION_SCHEMA.COLUMNS";
	strSql += " where TABLE_SCHEMA = '" + m_sDatabase + "'";
	String sTableName = objTable.m_sTableName;
	if (objTable.m_bFraction)
	{
		sTableName += "_00"; // 假设第一个分表
	}
	strSql += " and TABLE_NAME = '" + sTableName + "'";

	ScopedPtr<mysql::ResultSet> rs;
	rs.reset(conn->query(strSql));
	if (!rs)
	{
		return -1;
	}

	while (rs->next())
	{
		String sFieldName = rs->getString(0);
		String sDataType = rs->getString(1);
		String sFieldKey = rs->getString(2);

		// 字段与类型
		Json::ValueType valType = Json::ValueType::stringValue;
		if (sDataType.find("int") != std::string::npos)
		{
			valType = Json::ValueType::intValue;
		}
		objTable.m_mapField[sFieldName] = valType;

		// 主键
		if (sFieldKey.find("PRI") != std::string::npos)
		{
			objTable.m_vecKey.push_back(sFieldName);
		}
	}

	return 0;
}


} // namespace Sql
} // namespace Json

