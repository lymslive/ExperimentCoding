#! /bin/bash
# make byself fast find command
# refter to: http://docstore.mik.ua/orelly/unix3/upt/ch09_20.htm

egrep "$1" $HOME/.fastfind | sed "s@^@$HOME/@"
