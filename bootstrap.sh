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

gem install --user-install --no-rdoc --no-ri rake
rake_version=$(rake -V | sed -e 's/rake, version //')

rake _${rake_version}_ package:install:defaults
rake _${rake_version}_ setup
rake _${rake_version}_ install
gem uninstall --user-install --no-executables --version "= ${rake_version}" rake
