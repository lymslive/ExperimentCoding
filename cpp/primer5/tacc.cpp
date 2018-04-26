#include <iostream>
#include <vector>
#include <algorithm>
#include <numeric>
#include <typeinfo>

using namespace std;
int main()
{
	vector<double> dv = { 1.0, 2.5, 3, 4, 5 };
	auto result = accumulate(dv.cbegin(), dv.cend(), 0.0);
	cout << result << endl;
	cout << typeid(result).name() << " " << sizeof(result) << endl;
	return 0;
}

/*
 * accumulate 的加法行为，取决于第3个参数
 * */
