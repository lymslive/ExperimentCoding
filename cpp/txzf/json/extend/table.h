#ifndef JSON_EXTEND_TABLE_H__
#define JSON_EXTEND_TABLE_H__

#include "./config.h"
#include "../value.h"
#include "sqloper.h"

namespace Json {
namespace Sql {

class CTableMgr;
class CTable;
class CRecord;

// 表示一行记录的对象，内置 Json 对象存储数据
class CRecord
{
public:
	CRecord() : m_pTableMgr(NULL), m_pTable(NULL) {}
	CRecord(CTableMgr* pTableMgr, CTable* pTable) : m_pTableMgr(pTableMgr), m_pTable(pTable) {}

	// 代理 Json 对象
	Json::Value& operator[](const String& key);
	const Json::Value& operator[](const String& key) const;
	Json::Value& Json() { return m_jRecord; }

	// 是否有效字段
	inline bool isField(const String& sFieldName) const;
	// 当前是否存了该字段
	bool isMember(const String& sFieldName) const { return m_jRecord.isMember(sFieldName); }
	bool isBind() const { return m_pTableMgr && m_pTable; }

	// 按主键存取
	EINT Load(MysqlConnScopedPtr& conn); // select
	EINT Save(MysqlConnScopedPtr& conn); // update
	EINT SaveNew(MysqlConnScopedPtr& conn); // insert

	// 重载：指定非主键的筛选条件
	EINT Load(MysqlConnScopedPtr& conn, const Json::Value& jWhere);
	EINT Save(MysqlConnScopedPtr& conn, const Json::Value& jWhere);

	// 计算分表后缀
	String Fraction();
	// 猜测第一个条件字段也按主键规则分表
	String GuessFraction(const Json::Value& jWhere);
	// 直接指定分表
	CRecord& SetFraction(const String& sFraction);

	// 标记或屏蔽某些字段，影响连接数据库查询所用的列名
	CRecord& Mark(const String& sFieldName);
	CRecord& Mask(const String& sFieldName);
	CRecord& MarkAll();
	CRecord& operator+ (const String& sFieldName) { return Mark(sFieldName); }
	CRecord& operator- (const String& sFieldName) { return Mask(sFieldName); }

	// 返回列数
	int Size() const { return m_jRecord.size(); }
	int Cols() const { return Size(); }

	// 直接返回字段的值，默认是字符串，额外参数指定返回整数
	// 如果字段对应的 Json 值类型不符号，尽量尝试转化，否则返回零值
	String operator() (const String& sFieldName) { return StrField(sFieldName); }
	int operator() (const String& sFieldName, int) { return IntField(sFieldName); }
	String StrField(const String& sFieldName);
	int IntField(const String& sFieldName);

	// 不合法的字段，用一个静态 Json Value 表示
	static Json::Value& InvalidField();
	// 校验所有字段合法，删除不合法的字段，返回删除的个数
	int Valify();
private:
	CTableMgr* m_pTableMgr;
	CTable* m_pTable;
	Json::Value m_jRecord;
	String m_sFraction;
};

// 单一个表的类
class CTable
{
	friend class CTableMgr;
	friend class CRecord;
	public:
	typedef std::map<String, Json::ValueType> FieldMap;

	CTable() : m_bFraction(false) {}
	CTable(const String& sTableName, bool bFraction = false) : m_sTableName(sTableName), m_bFraction(bFraction) {}

	bool HasField(const String& sFieldName)
	{
		return m_mapField.count(sFieldName) > 0;
	}

	private:
	String m_sTableName; // 表名
	FieldMap m_mapField; // 每个字段的类型
	std::vector<String> m_vecKey; // 主键列表（可以多个）
	bool m_bFraction; // 是否分表设计
};

// 管理所有可用的表类
class CTableMgr
{
public:
	typedef std::map<String, CTable> TableMap;

	CTableMgr(const String& sDatabase) : m_sDatabase(sDatabase) {}

	// 创建一条记录对象，参数为表名（可选分表后缀名）
	// 空记录不在 Json 对象中预插字段
	CRecord Record(const String& sTableName);
	CRecord Record(const String& sTableName, const String& sFraction);
	CRecord EmptyRecord(const String& sTableName);
	CRecord EmptyRecord(const String& sTableName, const String& sFraction);

	EINT AddTable(MysqlConnScopedPtr& conn, const String& sTableName, bool bFraction = false);

	CTable* GetTable(const String& sTableName);
	String FullName(const String& sTableName)
	{
		return m_sDatabase + "." + sTableName;
	}

private:
	// 查询表名信息
	EINT QueryTable(MysqlConnScopedPtr& conn, CTable& objTable);
private:
	TableMap m_mapTable;
	String m_sDatabase; // 数据库名，默认的表名前缀
};

} // namespace Sql
} // namespace Json


#endif /* end of include guard: TABLE_H__ */
