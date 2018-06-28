# .bash_profile

echo ".bash_profile sourced!"

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

PATH=$HOME/bin:$PATH:$HOME/server/tools/base
PATH=$HOME/gitres/rakudobrew/bin:$PATH
PATH=$PATH:$HOME/.vim/perlx
PATH=$PATH:$HOME/server/tools/perlx
export PATH

# /etc/man.config -- will be overwrite if $MANPATH exported
MANPATH=~/share/man:/usr/man:/usr/share/man:/usr/local/man:/usr/local/share/man
export MANPATH

# longin shell prompt
# PS1='\[\033[01;32m\]\u@\h: \[\033[01;34m\]\w\n\[\033[01;32m\]!\!:\[\033[00m\]\$ '
PS1='\[\033[01;32m\]tsl@1.3: \[\033[01;34m\]\w\[\033[00m\]\$ '

# 严格按 ASCII 排序
# export LC_ALL=C

# ruby
# Load RVM into a shell session *as a function*
# [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
