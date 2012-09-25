#! /bin/zsh

function()
{
  {
    if --hzsh-is-caching; then
      # Run this in the background
      for f in ~/.zshrc ${cache}/zcomp-${HOST}; do
        zrecompile -qp ${f} && rm -f ${f}.zwc.old
      done
    fi

    if [[ ${OSTYPE} == darwin* ]]; then
      for env_var in PATH MANPATH; do
        launchctl setenv "$env_var" "${(P)env_var}" 2>/dev/null
      done
    fi
  } &!

  (( ${+options[interactive]} )) && (( ${+commands[fortune]} )) && fortune
}
