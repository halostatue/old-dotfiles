#! /bin/zsh

function hzsh_fortune()
{
  local is_interactive="$(set -o | grep -iw interactive | grep -iw on)"

  if [ -n "${is_interactive}" ]; then
    whence -w fortune >&| /dev/null && fortune
  fi
}

hzsh_fortune
unfunction hzsh_fortune
