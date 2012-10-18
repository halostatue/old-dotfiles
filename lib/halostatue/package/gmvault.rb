# -*- ruby encoding: utf-8 -*-

require 'halostatue/package'

class Halostatue::Package::GMVault < Halostatue::Package
  def install(task)
    unless installed? and target.join('bin/pip').exists?
      %x(which -s virtualenv)
      if $?.to_i.nonzero?
        require 'highline/import'

        say "Python virtualenv is not installed or not in your path."
        choose do |menu|
          menu.prompt = "Select one: "
          menu.choice("Install with 'pip install virtualenv'") {
            say "Installing virtualenv with pip."
            sh %q(pip install virtualenv)
          }
          menu.choice("Install with 'easy_install virtualenv'") {
            say "Installing virtualenv with easy_install."
            sh %q(easy_install virtualenv)
          }
          menu.choice("Install with 'sudo pip install virtualenv'") {
            say "Installing virtualenv with pip (using sudo)."
            sh %Q(sudo pip install virtualenv)
          }
          menu.choice("Install with 'sudo easy_install virtualenv'") {
            say "Installing virtualenv with easy_install (using sudo)."
            sh %Q(sudo easy_install virtualenv)
          }
          menu.choice("Cancel") {
            say "Cancelling install of gmvault."
            return
          }
        end
      end

      sh %Q(virtualenv --no-site-packages #{target})
    end

    update(task)
  end

  def uninstall(task)
    fail_unless_installed
    target.rmtree
  end

  def update(task)
    Dir.chdir(target.join('bin')) do
      sh %Q(./pip install --upgrade gmvault)
    end
  end
end
