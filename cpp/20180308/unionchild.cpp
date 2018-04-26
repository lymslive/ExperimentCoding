#include "unionchild.h"

CBase *CMyChild::GetChild()
{
	CBase *pChild = NULL;
	switch (m_cType)
	{
		case 'A':
			pChild = &m_Child.childA;
			break;
		case 'B':
			pChild = &m_Child.childB;
			break;
		case 'C':
			pChild = &m_Child.childC;
			break;
	}
	return pChild;
}

void CMyChild::Say()
{
	CBase *pChild = GetChild();
	if (pChild)
	{
		pChild->Hello();
	}
	else
	{
		cout << "no child at all!" << endl;
	}
}

int main()
{
	CMyChild object;
	object.Say();

	object.m_cType = 'A';
	object.Say();
	object.m_cType = 'B';
	object.Say();
	object.m_cType = 'C';
	object.Say();
}

/* output:
 * no child at all!
 * Hello A!
 * Hello B!
 * Hello C!
 */

// 联合里不允许存放带有构造函数、析够函数、复制拷贝操作符等的类，因为他们共享
// 内存，编译器无法保证这些对象不被破坏，也无法保证离开时调用析够函数
// union 成员可以是 struct，因为 struct 默认没有构造函数
