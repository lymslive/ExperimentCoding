#include <iostream>
#include <vector>
#include <algorithm>
#include <numeric>
#include <typeinfo>

using namespace std;
int main()
{
	int i;
	decltype(42) a;
	decltype(i) b;
	// decltype(std::move(i)) c;

	cout << typeid(a).name() << " " << sizeof(a) << endl;
	cout << typeid(b).name() << " " << sizeof(b) << endl;
	// cout << typeid(c).name() << " " << sizeof(c) << endl;
	return 0;
}

/*
 * decltype
 * */
