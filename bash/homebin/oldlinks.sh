#! /bin/sh
# print invalid soft links
# http://docstore.mik.ua/orelly/unix3/upt/ch08_16.htm

find . -type l - print | perl -nle '-e || print'
