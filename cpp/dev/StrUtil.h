#ifndef STRUTIL_H__
#define STRUTIL_H__

#include <vector>
#include "CString.h"

std::vector<CString> split(const char* str, char cSep);
std::vector<CString> split(const char* str, const char* pSep);

#if 0
template <class StrT>
std::vector<CString> split<StrT>(const StrT& str, char cSep);
template <class StrT>
std::vector<CString> split<StrT>(const StrT& str, const char* pSep);
#endif

#endif /* end of include guard: STRUTIL_H__ */
