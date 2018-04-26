#include <iostream>
using namespace std;

struct Stu
{
	void Foo() { cout << "Stu::Foo()" << endl; }
	void Bar();
};

void Stu::Bar()
{
	cout << "Stu::Bar()" << endl;
}

int main(int argc, char *argv[])
{
	Stu *pSt = NULL;
	pSt->Foo();
	pSt->Bar();
	return 0;
}

/*
 * 空指针可以调用函数的。函数地址按类的偏移。
 */
