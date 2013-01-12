# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/definition'

class Halostatue::Package::Definition::ZshCompletions < Halostatue::Package
  include Halostatue::Package::Type::Git

  default_package
  url "git://github.com/zsh-users/zsh-completions.git"
  has_plugin

  def plugin_init_file
    <<-EOS
# Put zshcompletions first
fpath=("#{target.join('src')}" ${fpath})
    EOS
  end
end
