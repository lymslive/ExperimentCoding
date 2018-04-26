#include <boost/regex.hpp>
#include <iostream>
#include <string>

int main()
{
	std::string line;
	boost::regex pat("^Subject: (Re: |Aw: )*(.*)");
	while (std::cin)
	{
		std::getline(std::cin, line);
		boost::smatch matches;
		if (boost::regex_match(line, matches, pat))
			std::cout << matches[2] << std::endl;
	}
}

/* 说明:
 * 需指定链接库编译
 * $ g++ exregex.cpp -L/usr/local/lib/ -lboost_regex
 */
