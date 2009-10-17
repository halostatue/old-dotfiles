#!/bin/bash

# Set things up for work:

[ -f /evault/profile ] && source /evault/profile

# Set things up normally
source ~/.bash/aliases
source ~/.bash/completions
source ~/.bash/paths
source ~/.bash/config

if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi
