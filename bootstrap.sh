#! /bin/zsh

builtin echo "Bootstrap halozsh."
home_path=$(builtin cd ~; builtin pwd -P)

for candidate in $(gem env gempath | sed -e 's/:/ /'); do
  case "${candidate}" in
    ${home_path}/.gem/ruby/*|*/.gem/ruby/*)
      PATH=${candidate}/bin:${PATH}
      break
      ;;
  esac
done

gem install --user-install --no-roc --no-ri rake
rake_version=$(rake -V | sed -e 's/rake, version //')

rake package:install:defaults
rake setup
rake install
gem uninstall --user-install --version "= ${rake_version}" rake
