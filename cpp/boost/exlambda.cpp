#include <boost/lambda/lambda.hpp>
#include <iostream>
#include <iterator>
#include <algorithm>

int main()
{
	using namespace boost::lambda;
	typedef std::istream_iterator<int> in;
	std::for_each(in(std::cin), in(), std::cout<< (_1 * 3) << " ");
}

/* 说明：
 * 公司系统 CenterOS6.5 已装 boost 在目录 /usr/local/include/boost
 * 示例可运行，直接编译
 * NeoComplete 插件不能补全包含文件路径
 * 但 clang_complete 插件可正确编译提示 boost 类成员
 * */
