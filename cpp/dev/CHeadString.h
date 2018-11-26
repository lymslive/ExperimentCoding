#ifndef CHEADSTRING_H__
#define CHEADSTRING_H__
/* 前缀字符串：
 * 在字符串缓冲区头部存放 1/2/4 字节表示字长串长度，NULL 字符除外
 * 头部用模板参数（不同大小的整数类型）表示
 */

#include <cstring>

template <class HeadT>
class CHeadString
{
public:
	CHeadString() m_pData(NULL) {}
	CHeadString(const char* str);
	CHeadString(size_t n, char c = ' ');
	CHeadString(const CHeadString<HeadU>& that);

public:
	~CHeadString() { _free(); }

	size_t head() const { return sizeof(HeadT); }
	size_t length() const;

	size_t size() const { return length(); }
	size_t sizeall() const { return head() + length() + 1; }
	size_t sizemax() const { return ~(static_cast<HeadT>(0)); }
	size_t maxlen() const { return sizemax() - head() - 1;}

	const char* c_str() const { return m_pData; }

	CHeadString& operator= (const CHeadString<HeadU>& that);

	bool operator== (const CHeadString<HeadU>& that) const;
	bool operator!= (const CHeadString<HeadU>& that) const { return !(*this == that); }
	bool operator<  (const CHeadString<HeadU>& that) const;
	bool operator>= (const CHeadString<HeadU>& that) const { return !(*this < that); }
	bool operator>  (const CHeadString<HeadU>& that) const { return that < *this; }
	bool operator<= (const CHeadString<HeadU>& that) const { return !(that < *this); }

private:
	void _copy(const CHeadString<HeadU>& that);
	void _free();
	char _alloc(size_t iLength);

private:
	char* m_pData;
};

typedef CHeadString<unsigned char> H1Str;
typedef CHeadString<uint16_t> H2Str;
typedef CHeadString<uint32_t> H4Str;

template <class HeadT>
size_t CHeadString<HeadT>::length() const
{
	if (!m_pData)
	{
		return 0;
	}

	HeadT* pHead = reinterpret_cast<HeadT*>(m_pData) - 1;
	return *pHead;
}

template <class HeadT>
size_t CHeadString<HeadT>::CHeadString(const char* str) : m_pData(NULL)
{
	if (!str)
	{
		return;
	}

	size_t iLength = strlen(str);
	if (iLength > maxlen())
	{
		return;
	}

	char* m_pData = _alloc(iLength);
	if (!m_pData)
	{
		return;
	}

	strcpy(m_pData, str);
}

template <class HeadT>
size_t CHeadString<HeadT>::CHeadString(size_t n, char c) : m_pData(NULL)
{
	if (n > maxlen())
	{
		return;
	}

	char* m_pData = _alloc(n);
	if (!m_pData)
	{
		return;
	}

	memset(m_pData, c, n);
	m_pData[n] = '\0';
}

template <class HeadT>
size_t CHeadString<HeadT>::CHeadString(const CHeadString<HeadU>& that) : m_pData(NULL)
{
	if (!that.m_pData)
	{
		return;
	}

	_copy();
}

template <class HeadT>
CHeadString<HeadT>& CHeadString<HeadT>::operator=(const CHeadString<HeadU>& that) 
{
	if (sizeof(HeadT) == sizeof(HeadU) && this.m_pData == that.m_pData)
	{
		return *this;
	}

	if (m_pData)
	{
		_free();
	}

	if (!that.m_pData)
	{
		return *this;
	}

	_copy(that);
	return *this;
}

template <class HeadT>
void CHeadString<HeadT>::_copy(const CHeadString<HeadU>& that) 
{
	size_t n = that.length();
	if (n > maxlen())
	{
		return;
	}

	char* m_pData = _alloc(n);
	if (!m_pData)
	{
		return;
	}

	strcpy(m_pData, that.m_pData);
}

template <class HeadT>
void CHeadString<HeadT>::_free() 
{
	if (!m_pData)
	{
		return;
	}

	char *pMem = m_pData - head();
	free(pMem);
	m_pData = NULL;
}

template <class HeadT>
char* CHeadString<HeadT>::_alloc(size_t iLength) 
{
	size_t iSizeAll = head() + iLength + 1;
	char *pMem = malloc(iSizeAll);
	if (!pMem)
	{
		return NULL;
	}

	HeadT* pHead = reinterpret_cast<HeadT*>(m_pMem);
	*pHead = iLength;
	return pMem + head();
}

template <class HeadT>
bool CHeadString<HeadT>::operator==(const CHeadString<HeadU>& that)
{
	if (m_pData == that.m_pData)
	{
		return true;
	}
	if (that.length() != length())
	{
		return false;
	}
	return strcmp(m_pData, that.m_pData) == 0;
}

template <class HeadT>
bool CHeadString<HeadT>::operator<(const CHeadString<HeadU>& that)
{
	size_t iThis = length();
	size_t iThat = that.length();
	if (iThis < iThat)
	{
		return true;
	}
	else if (iThis > iThat)
	{
		return false;
	}

	return strcmp(m_pData, that.m_pData) < 0;
}

#endif /* end of include guard: CHEADSTRING_H__ */
