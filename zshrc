#! /bin/zsh

# Based in part on: http://www.jukie.net/~bart/conf/zshrc
#
# Modified to allow for autoloaded functions being loaded before loading
# scriptlets.

autoload -U compinit zrecompile is-at-least

zsh_cache=${HOME}/.zsh_cache
mkdir -p ${zsh_cache}

if [ ${UID} -eq 0 ]; then
  # Ignore insecure directories.
  compinit -i
else
  compinit -d ${zsh_cache}/zcomp-${HOST}

  for f in ~/.zshrc ${zsh_cache}/zcomp-${HOST}; do
    zrecompile -qp ${f} && rm -f ${f}.zwc.old
  done
fi

setopt extended_glob

fpath=(~/.zsh/functions ~/.zsh/prompts ${fpath})

if [[ -d ~/.zsh/${OSTYPE}/functions ]]; then
  fpath=(~/.zsh/${OSTYPE}/functions ${fpath})
fi

# Zsh prior to 4.3.10 doesn't support %u/%c for un/staged characters. So let's
# use these 4.3.11 versions that I pulled in from the zsh source (vendored in
# vendor/zsh). 4.3.6 seems like a safe point to stop including, at least for
# now.
if is-at-least 4.3.6 && ! is-at-least 4.3.11; then
  fpath=(~/.zsh/vcs-info ${fpath})
fi

# zstyle :hzsh:plugins:ssh-agent agent-forwarding on
zstyle :hzsh:plugins:ssh-agent all-identities yes

# Autoload everything in $fpath.
autoload -U $^fpath/*(N.:t)

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
[ -f ~/.localrc ] && source ~/.localrc

# Use 'command-not-found' on platforms where it's installed.
[ -f /etc/zsh_command_not_found ] && source /etc/zsh_command_not_found

# Make sure our default prompt shows 0.
return 0
