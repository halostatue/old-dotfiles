#! /bin/zsh

# hzsh: Halostatue Zsh init scripts.
#
# Based on a lot of different influences, including but not limited to:
#   * Bart Trojanowski: http://www.jukie.net/~bart/conf/zshrc
#   * oh-my-zsh: https://github.com/robbyrussell/oh-my-zsh/

# Enable plug-ins that do not have detection files.
zstyle :hzsh:plugins enabled pybugz

# Set ssh-agent plug-in options.
zstyle :hzsh:plugins:ssh-agent agent-forwarding on
zstyle :hzsh:plugins:ssh-agent all-identities yes

# Set the prompt name and the options to be used when setting the prompt. This
# is done just before returning from the setup. In this way, prompts may depend
# on things in plug-ins, too.
zstyle :hzsh:prompt options austin2 noverbose

# Enable support for these version control systems. Assumes your prompt uses
# vcs_info. The austin2 prompt does.
zstyle :hzsh:prompt:vcs_info enable git cvs svn hg bzr

# Do the real work of loading based on the above settings and the defaults in
# the prompt management scripts.
source ${HOME}/.zsh/loader
