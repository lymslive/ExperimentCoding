# .bashrc

echo ".bashrc sourced!"

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# nonlogin bash
# print before PS1, print right and \r return to left inline
PROMPT_COMMAND='printf "%${COLUMNS}s\r" "$(date +%T)<<$SHLVL"'
PS1='\[\033[01;32m\]!\!: \[\033[01;34m\]\w\[\033[00m\]\$ '

alias psu='ps -fu `whoami`'
alias tailfe='tail -f `ls -rt *.error | tail -1`'
alias tailfg='tail -f `ls -rt zone_svr_20*.log | tail -1`'
alias tailfr='tail -f `ls -rt rundata*.log | tail -1`'

alias pd=pushd
alias pd2='pushd +2'
alias pd3='pushd +3'
alias pd4='pushd +4'

alias mz='make -j4 zone_svr'

# 'cd var' will try 'cd $var'
shopt -s cdable_vars

alias mark='mark=$PWD'
unalias vi

CDPATH=:$HOME:$HOME/server
export CDPATH

export PAGER=less
export EDITOR=vim

z=zone_svr

c()
{
   dir="$1"

   # Replace every dot with */
   # Add a final "/." to be sure this only matches a directory:
   dirpat="`echo $dir | sed 's/\./*\//g'`*/."

   # In case $dirpat is empty, set dummy "x" then shift it away:
   set x $dirpat; shift

   # Do the cd if we got one match, else print error:
   if [ "$1" = "$dirpat" ]; then
      # pattern didn't match (shell didn't expand it)
      echo "c: no match for $dirpat" 1>&2
   elif [ $# = 1 ]; then
      echo "$1"
      cd "$1"
   else
      echo "c: too many matches for $dir:" 1>&2
      ls -d "$@"
   fi

   unset dir dirpat
}

# perl @INC .pm search path
export PERL5LIB=$HOME/.perl:$HOME/perl5/lib/perl5

# ruby: Add RVM to PATH for scripting
# export PATH="$PATH:$HOME/.rvm/bin"

# go
export GOROOT=$HOME/share/go
export GOPATH=$HOME/.go
PATH=$HOME/share/go/bin:$GOPATH/bin:$PATH
# :$HOME/study/go
