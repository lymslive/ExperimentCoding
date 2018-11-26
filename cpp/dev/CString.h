#ifndef CSTRING_H__
#define CSTRING_H__

#include "CStaticString.h"

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


#endif /* end of include guard: CSTRING_H__ */
