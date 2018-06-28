#! /bin/bash
# make byself fast find dbupdate
# refter to: http://docstore.mik.ua/orelly/unix3/upt/ch09_20.htm

cd
find . -print | sed "s@^./@@" > .fastfind.new
mv -f .fastfind.new .fastfind
