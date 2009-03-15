#! /bin/zsh

whence fortune > /dev/null 2>&1 && fortune

# go to saved path if there is one
if [[ -f ~/.current_path~ ]]; then
  cd `cat ~/.current_path~`
  rm ~/.current_path~
fi
