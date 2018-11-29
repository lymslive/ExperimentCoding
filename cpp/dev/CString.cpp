#include "CString.h"
#include <new>

CString::CString(const char* pStr)
{
	if (pStr == NULL)
	{
		return;
	}
	_copy(pStr, strlen(pStr));
}

CString::CString(const CString& that)
{
	_copy(that.c_str(), that.length());
}

CString::CString(const CStr& that)
{
	_copy(that.c_str(), that.length());
}

CString& CString::operator= (const CString& that)
{
	if (this == &that)
	{
		return *this;
	}
	_free();
	_copy(that.c_str(), that.length());
	return *this;
}

CString& CString::operator= (const char* pthat)
{
	_free();
	_copy(pthat, strlen(pthat));
	return *this;
}

CString CString::operator+ (const char* pthat)
{
	if (pthat == NULL)
	{
		return *this;
	}

	CString result;
	size_t iLength = strlen(pthat);
	result.len = len + iLength;
	char* ptr = _alloc(result.len);
	if (ptr != NULL)
	{
		if (c_str() != NULL)
		{
			strcpy(ptr, c_str());
		}
		strcpy(ptr + len, pthat);
	}
	result.str = const_cast<const char*>(ptr);
	return result;
}

CString& CString::operator+= (const char* pthat)
{
	if (pthat == NULL)
	{
		return *this;
	}

	size_t iLength = len + strlen(pthat);
	char* ptr = _alloc(iLength);
	if (ptr != NULL)
	{
		if (c_str() != NULL)
		{
			strcpy(ptr, c_str());
		}
		strcpy(ptr + len, pthat);
		_free();
		str = const_cast<const char*>(ptr);
		len = iLength;
	}
	return *this;
}

char* CString::_alloc(size_t n)
{
	char *pNew = static_cast<char*>(::operator new(n+1));
	pNew[n] = '\0';
	return pNew;
}

void CString::_free()
{
	if (str != NULL)
	{
		char *ptr = const_cast<char*>(str);
		::operator delete(ptr);
		str = NULL;
	}
}

void CString::_copy(const char* pStr, size_t iLength)
{
	this->len = iLength;
	if (this->len <= 0 || pStr == NULL)
	{
		this->str = NULL;
		return;
	}

	char *ptr = _alloc(this->len);
	if (ptr == NULL)
	{
		return;
	}
	strcpy(ptr, pStr);
	this->str = const_cast<const char*>(ptr);
}

CStrbuf::CStrbuf(const char* pStr) : CString(pStr)
{
	cap = len;
}

CStrbuf::CStrbuf(const CStr& that) : CString(that)
{
	cap = len;
}

CStrbuf::CStrbuf(size_t nCap)
{
	len = 0;
	str = const_cast<const char*>(_alloc(nCap));
	cap = nCap;
}

CStrbuf::CStrbuf(const CStrbuf& that)
{
	len = that.len;
	cap = that.cap;
	char *ptr = _alloc(cap);
	strcpy(ptr, that.c_str());
	str = const_cast<const char*>(ptr);
}

CStrbuf& CStrbuf::reserve(size_t nCap)
{
	if (nCap > cap)
	{
		_realloc(nCap);
	}
	return *this;
}

CString* CStrbuf::fixstr(size_t cutlen)
{
	size_t nCap = this->len;
	if (cutlen > 0 && cutlen < this->len)
	{
		nCap = cutlen;
	}
	_realloc(nCap);
	// return static_cast<CString*>(this);
	return this;
}

void CStrbuf::_realloc(size_t n)
{
	char *ptr = _alloc(n);
	if (ptr == NULL)
	{
		return;
	}
	if (this->str != NULL)
	{
		if (n <= this->len)
		{
			strncpy(ptr, this->str, n);
		}
		else
		{
			strcpy(ptr, this->str);
		}
	}
	_free();
	this->str = const_cast<const char*>(ptr);
	this->cap = n;
}

CStrbuf& CStrbuf::operator= (const CStrbuf& that)
{
	if (this == &that)
	{
		return *this;
	}
	_free();
	len = that.len;
	cap = that.cap;
	char *ptr = _alloc(cap);
	strcpy(ptr, that.c_str());
	str = const_cast<const char*>(ptr);
	return *this;
}

CStrbuf& CStrbuf::operator= (const char* pthat)
{
	_free();
	_copy(pthat, strlen(pthat));
	cap = len;
	return *this;
}

CStrbuf& CStrbuf::operator+= (const char* pthat)
{
	_append(pthat, strlen(pthat));
	return *this;
}

CStrbuf CStrbuf::operator+ (const char* pthat)
{
	if (pthat == NULL)
	{
		return *this;
	}

	size_t nCap = this->len + strlen(pthat);
	CStrbuf result(nCap);
	char* ptr = const_cast<char*>(result.str);
	strcpy(ptr, this->str);
	strcpy(ptr + this->len, pthat);
	result.len = result.cap;
	return result;
}

void CStrbuf::_append(const char* pStr, size_t iLength)
{
	size_t newLen = this->len + iLength;
	if (newLen > this->cap)
	{
		size_t nCap = cap + (newLen - cap) * 2;
		reserve(nCap);
	}
	char* ptr = const_cast<char*>(str);
	strcpy(ptr + len, pStr);
	len = newLen;
	ptr[len] = '\0';
}

