#include "unionstruct.h"
#include <iostream>

using namespace std;

int main()
{
	UStruct us;
	us.A.a = 38;
	cout << us.A.a << endl;

	cout << us.B.b << endl;

	cout << us.C.c << endl;
}
