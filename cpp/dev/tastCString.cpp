#include <cstdio>
#include <cstdlib>
#include "CString.h"
#include <ctype.h>

void disp(const char* msg, const CStr& s) 
{
	printf("%s: [0x%x][%d]->%s\n", msg, s.c_str(), s.length(), s.c_str());
}

void disp(const char* msg, const CStrbuf& s) 
{
	printf("%s: [0x%x][%d/%d]->%s\n", msg, s.c_str(), s.length(), s.capcity(), s.c_str());
}

void report_section(const char* msg)
{
	printf("/* *********** %s *********** */\n", msg);
}

#define DISP(s) disp(#s, s)
#define TAST(s) report_section(s)

int main(int argc, char *argv[])
{
	const char* pLit1 = "hello";
	const char* pLit2 = "world";

	CStr objStr1(pLit1);
	CStr objStr2(pLit2);

	// 隐含转化 const char*
	// printf("use CStr as const char*: %s %s\n", objStr1, objStr2);
	printf("use CStr as const char*: %s %s\n", objStr1.c_str(), objStr2.c_str());
	printf("use CStr as const char*: %s cmp %s: %d\n", objStr1.c_str(), objStr2.c_str(), strcmp(objStr1, objStr2));

	printf("use CStr[]: %c %c\n", objStr1[0], objStr2[0]);
	// objStr1[0] = 'H'; // 指向文本区的字符串，不可修改
	// objStr2[0] = 'W';
	printf("use CStr[] modify: %s %s\n", objStr1.c_str(), objStr2.c_str());

	printf("compare str %s < %s :%d\n", objStr1.c_str(), objStr2.c_str(), objStr1 < objStr2);
	printf("compare str %s > %s :%d\n", objStr1.c_str(), objStr2.c_str(), objStr1 > objStr2);

	CString objString1(pLit1);
	CString objString2(objString1);

	// 地址测试
	printf("address pLit1: %x\n", pLit1);
	printf("address pLit2: %x\n", pLit2); // 文本区的字面文本，地址没空隙
	printf("address objStr1: %x\n", objStr1.c_str());
	printf("address objStr2: %x\n", objStr2.c_str());
	printf("address objString1: %x\n", objString1.c_str());
	printf("address objString2: %x\n", objString2.c_str());

	char aStr1[8] = "aaaaa";
	char aStr2[8] = "bbbbb";
	printf("address aStr1: %x\n", aStr1);
	printf("address aStr2: %x; diff: %d\n", aStr2, aStr1-aStr2);
	// -> 栈空间的地址有对齐空隙? 或者短数组本身至少 16 字节？

	CStr objStr3(aStr1);
	CStr objStr4(aStr2);
	printf("use CStr[] modify: %s %s\n", objStr3.c_str(), objStr4.c_str());
	objStr3[0] = 'H';
	objStr4[0] = 'W';
	printf("use CStr[] modify: %s %s\n", objStr3.c_str(), objStr4.c_str());

	// 修改字符串元素内容
	objString2[1] = 'X';
	disp("objString2", objString2);
	disp("objString1", objString1);

	for (char* it = objString1.begin(); it != objString1.end(); ++it)
	{
		*it = toupper(*it);
	}
	disp("upcase objString1", objString1);

	// CString 运算测试
	TAST("CString operator");
	CString objString3 = objString1;
	DISP(objString1);
	char *pTmp = new char[8];
	objString1 = objString1 + objString2 + objString1;
	delete[] pTmp;
	DISP(objString1);
	DISP(objString2);
	DISP(objString3);
	
	objString1 = objString1 + "codein string";
	DISP(objString1);
	objString1 += "-----";
	DISP(objString1);
	objString1 += objString2;
	DISP(objString1);
	DISP(objString2);

	pTmp = new char[8];
	objString2 = "---xxx---";
	delete[] pTmp;
	DISP(objString2);
	// -> CString 的赋值，先 free 再 copy ，有可能重新申请到原来那块内存
	// 这可能减少内存消耗，但赋值失败时原内容已被清空

	// CStrbuf 运算测试
	TAST("CStrbuf operator");
	CStrbuf sbuf0, sbuf1(pLit1), sbuf2(objStr2), sbuf3(objString3);
	DISP(sbuf0);
	DISP(sbuf1);
	DISP(sbuf2);
	DISP(sbuf3);

	CStrbuf sbuf4 = "CStrbuf litte string";
	DISP(sbuf4);
	sbuf4 = "CStrbuf litte STRING";
	DISP(sbuf4);

	sbuf4 = sbuf3 + objString2 + objStr1 + pLit1;
	DISP(sbuf4);
	DISP(sbuf1);
	sbuf1 += sbuf2;
	DISP(sbuf1);
	DISP(sbuf2);

	sbuf1 += objStr2;
	DISP(sbuf1);
	sbuf1 += objString3;
	DISP(sbuf1);

	sbuf0 += sbuf1;
	DISP(sbuf0);
	sbuf0 << sbuf1 << " " << objStr2 << " " << objString3 << "!!";
	DISP(sbuf0);
	return 0;
}
