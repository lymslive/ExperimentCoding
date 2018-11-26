#! /bin/env python3

import common
import os
import sys

target = sys.argv[1]

def hello(str):
	common.hello(str)
	print('Hello ' + str + 'in Local')
	print('common.VERSION = ' + common.VERSION)
	print('common.VERSION =', common.VERSION)

if __name__ == '__main__':
	print(os.getcwd())
	os.chdir(target)
	print(os.getcwd())
	hello('python')

"""
import 模块的相对路径，是相对当前脚本，而不是工作目录。
"""
