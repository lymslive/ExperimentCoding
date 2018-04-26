#ifndef UNIONCHILD_H__
#define UNIONCHILD_H__

#include <iostream>
using namespace std;

class CBase
{
public:
	virtual void Hello() = 0;
};

class CChildA : public CBase
{
public:
	virtual void Hello() { cout << "Hello A!" << endl; }
};

class CChildB : public CBase
{
public:
	virtual void Hello() { cout << "Hello B!" << endl; }
};

class CChildC : public CBase
{
public:
	virtual void Hello() { cout << "Hello C!" << endl; }
};

// union UChild
struct UChild
{
	CChildA childA;
	CChildB childB;
	CChildC childC;
};

class CMyChild
{
public:
	char m_cType;
	UChild m_Child;
	CBase *GetChild();
	void Say();
};

#endif /* end of include guard: UNIONCHILD_H__ */
