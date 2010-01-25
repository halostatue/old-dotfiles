#!/bin/bash

# Set things up for work:

[ -f /evault/profile ] && source /evault/profile

# Set things up normally

# if [[ -d ~/.bash/rc.d ]]; then
#   for script in `ls ~/.bash/rc.d/* | sort`; do
#     soure ${script}
#   done
# fi

source ~/.bash/aliases
source ~/.bash/completions
source ~/.bash/paths
source ~/.bash/config
source ~/.bash/go

if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi

whence fortune > /dev/null 2>&1 && fortune

# go to saved path if there is one
if [[ -f ~/.current_path~ ]]; then
  cd `cat ~/.current_path~`
  rm ~/.current_path~
fi
