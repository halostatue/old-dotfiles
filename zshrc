#! /bin/zsh

# Based in part on: http://www.jukie.net/~bart/conf/zshrc
# 
# Modified to allow for autoloaded functions being loaded before loading
# scriptlets.

autoload -U compinit zrecompile is-at-least

zsh_cache=${HOME}/.zsh_cache
mkdir -p ${zsh_cache}

if [ ${UID} -eq 0 ]; then
  compinit
else
  compinit -d ${zsh_cache}/zcomp-${HOST}

  for f in ~/.zshrc ${zsh_cache}/zcomp-${HOST}; do
    zrecompile -qp ${f} && rm -f ${f}.zwc.old
  done
fi

setopt extended_glob

fpath=(~/.zsh/functions ~/.zsh/git/functions ${fpath})

if [ -d ~/zwork ]; then
  fpath=(~/zwork ${fpath})
fi

platform=$(uname | tr A-Z a-z)
if [[ -d ~/.zsh/functions/${platform} ]]; then
  fpath=(~/.zsh/functions/${platform} ${fpath})
fi

# Autoload everything in $fpath.
autoload -U $^fpath/*(N.:t)

if has brew; then
  autoload -U $(brew --prefix)/Library/Contributions/brew_zsh_completion.zsh
fi

if [[ -d ~/.zsh/rc.d ]]; then
  scriptlets=(~/.zsh/rc.d/[0-9][0-9]*[^~](.N))
  if [ -n "${scriptlets}" ]; then
    for zshrc_scriptlet in ${scriptlets}; do
      case ${zshrc_scriptlet} in
        *DISABLED)  ;;
        *)          source ${zshrc_scriptlet} ;;
      esac
    done
  fi
fi

# use .localrc for settings specific to one system
[[ -f ~/.localrc ]] && source ~/.localrc
