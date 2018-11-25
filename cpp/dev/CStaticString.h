#ifndef CSTATICSTRING_H__
#define CSTATICSTRING_H__

#include <cstring>
#include <vector>

// 表示一个字符串的纯粹的结构体
// typedef StructString SStr
struct SStr
{
	size_t len;
	char* str;

	SStr() : len(0), str(NULL);
	SStr(const char* pStr) : len(strlen(pStr)), str(pStr);
};

// 静态字符串类，不申请额外保存空间
// 用户保证指针所批的字符串缓冲区生存空间长于本对象
// 例如适于表示字面字符串
// typedef CStaticString CStr
class CStr : protected SStr
{
public:
	CStr() {}
	CStr(const char* pStr) : SStr(pStr);

	size_t length() const { return len; }

	// c_str() 与 c_end() 可当作迭代器使用
	const char* c_str() const { return str; }
	const char* c_end() const { return str + len; }
	char* begin() { return str; }
	char* end() { return str + len; }

	// 直接当成C字符串指针使用
	operator const char* () const { return str;}

	bool operator<= (const CStr& that) const
	{
		return str == that.str || strcmp(str, that.str) <= 0;
	}
	bool operator== (const CStr& that) const
	{
		return str == that.str || (len == that.len && strcmp(str, that.str) == 0);
	}

	// 索引未检查越界，像原始字符指针使用
	char& operator[](size_t i) { return str[i]; }
	const char& operator[](size_t i) const { return str[i]; }

};

// 不可变字符串，当作字符串值使用，有独立的存储空间
// typedef CConstString CString
class CString : public CStr
{
public:
	CString() {}
	CString(const char* pStr);
	CString(const CString& that);
	~CString() { _free(); }

	CString& operator= (const CString& that);
	CString& operator+ (const CString& that);

	std::vector<CString> split(char cSep) const;
	std::vector<CString> split(const char* pSep) const;

protected:
	void _alloc(size_t n);
	void _free();
};

// 用于构造可增长的字符串
// 成员变量 cap len str
class CStrbuf : public CString
{
public:
	CStrbuf() : CString(), cap(0) {}
	CStrbuf(const char* pStr);
	CStrbuf(size_t nCap);
	// ~CStrbuf() { _free(); }

	CStrbuf& operator+= (const CString& that);
	CStrbuf& operator+ (const CString& that);
	CStrbuf& operator+= (const char* pthat);
	CStrbuf& operator+ (const char* pthat);

	CStrbuf& reserve(nCap);
	// 删除冗余空间，并将自己强转为基类返回
	CString& fixstr();

private:
	CStrbuf(const CStrbuf& that);
	CStrbuf& operator= (const CStrbuf& that);
private:
	size_t cap;
};

#endif /* end of include guard: CSTATICSTRING_H__ */
