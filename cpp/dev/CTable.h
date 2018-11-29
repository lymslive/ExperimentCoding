#ifndef CTABLE_H__
#define CTABLE_H__

#include <vector>
#include "CHString.h"
#include "CScalar.h"

// 表示数据库的一个表结构
class CTable
{
public:
	CTable();
	~CTable();

	int Init();

	// 分表函数指针
	typedef CHString SplitorFun(const char* pValue);

	// 表示一个字段的结构
	// 字段名附在该结构体之后，NULL 结束的字符串
	// 结构末字节（字符串前一字节）是字段名长度，最大 256
	struct SField
	{
		uint8_t idx;  // 列序号，最大 256 列
		uint8_t type; // 列类型
		// uint8_t info;
		uint8_t prikey : 1;  // 是否主键
		uint8_t unqkey : 1;  // 是否唯一
		uint8_t nonull : 1;  // 不允许非空
		uint8_t hasdef : 1;  // 有默认值
		uint8_t NOTUSE : 4;
		uint8_t length;

		int Size() const { return sizeof(*this) + length; }
		const char* Name() const { return static_cast<const char*>(this+1); }
	};

	// 字段的值类型，非数据在内部都用字符串表达
	enum FieldType
	{
		FIELD_VALUE_NULL = 0,
		FIELD_VALUE_INT = 1,
		FIELD_VALUE_DOUBLE = 2,
		FIELD_VALUE_ULONG = 3,
		FIELD_VALUE_STRING = 4,
		FIELD_VALUE_DATETIME = 5,
		FIELD_VALUE_TEXTBLOB = 6,
	};

	// 查找一个字段，不存在时返回 NULL
	const SField* FindField(const char* pStr);
	const SField* FindField(const char* pStr, size_t iLength);
	const SField* FindField(const char* pStr, const char* pEnd);

private:
	void addField(const SField& stField);
	void sortField();
	bool cmpFieldPtr(const SField* p1, const SField* p2);

	CHString m_sTableName;
	std::vector<SField*> m_vecFields;
	SplitorFun m_pfSplitor;
};

class CRecord
{
public:
	CRecord();
	~CRecord();

	// 根据字符串索引字段值
	CScalar& operator[] (const char* pField);
	const CScalar& operator[] (const char* pField) const;

	// 根据列序号索引字段值
	CScalar& operator[] (size_t idx);
	const CScalar& operator[] (size_t idx) const;

	// 标记/屏蔽关注的字段
	CRecord& Mark(const char* pField);
	CRecord& Mask(const char* pField);
	CRecord& MarkAll();

private:
	CTable* m_pTable;
	std::map<CTable::SField*, CScalar> m_mapField;
};

class CTableMgr
{
public:

private:
	void addTable(const CTable& objTable);
	void sortTable();
	bool cmpTable(const CTable& t1, const CTable& t2);

	CHString m_sBaseName;
	std::vector<CTable> m_vecTable;
};

#endif /* end of include guard: CTABLE_H__ */
