# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/type'

class Halostatue::Package::Powerline < Halostatue::Package
  include Halostatue::Package::Type::Git
  url "git://github.com/milkbikis/powerline-bash"
  has_plugin

  def plugin_functions
    {
      :prompt_powerline_setup  => zsh_autoload(prompt_powerline_setup),
    }
  end

  def prompt_powerline_setup
    <<-EOS
setopt prompt_subst

PROMPT="\$(#{target.join('powerline-bash.py')} ${?} --shell zsh)"
RPROMPT=
    EOS
  end
end
