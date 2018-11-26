#! /bin/env python3

import sys
target = sys.argv[1]

import os
print(os.getcwd())

print('Hello in client')

os.chdir(target)
import common
print(os.getcwd())

common.hello('from client')

"""
import 模块的相对路径，是相对当前脚本，而不是工作目录。
"""
