# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'
require 'halostatue/package/type'

class Halostatue::Package::Zshsyntaxhighlighting < Halostatue::Package
  include Halostatue::Package::Type::Git
  url "git://github.com/zsh-users/zsh-syntax-highlighting.git"

  has_plugin

  def plugin_init_file
    <<-EOS
source "#{target.join('zsh-syntax-highlighting.zsh')}"
    EOS
  end
end
