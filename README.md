# halostatue's Zsh Configuration

This has the configuration files and standard scripts that I use for
everything except vim configuration on Unixish hosts (primarily Mac OS X
and Ubuntu Linux). My vim configuration is a separate repository for
historical and practical reasons.

## Prerequisites

* Ruby 1.8.7 or later
* Rake 0.9.2 or later (`[sudo] gem install rake` as needed).

## Installation

    git clone git://github.com/halostatue/dotfiles ~/.dotfiles
    cd ~/.dotfiles
    rake -T # prints out the files that have <.replace> in them
    rake install # Installs the config

### Template Files

Files can be installed in one of two ways: linking or template
generation. A *template* file is one that will be run through `erb` to
evaluate the contents of the file. The output will be written as the
install target.

A method `include_file` is available to include the contents of another
file (included files are automatically treated like template files).
Relative paths may be given to `include_file`; they will be expanded
(using `expand_path`) on use. If the `include_file` path includes the
string `{PLATFORM}`, it will be replaced with the equivalent of `uname |
tr A-Z a-z`.

Files that are installed by template are given named tasks, in the
`file` namespace:

    rake file:gitconfig   # Includes: ~/.github-token, include/gitconfig.darwin
    rake file:hgrc        # Includes: include/hgrc.darwin
    rake file:ssh-config  # Includes: ~/.ssh-home, ~/.ssh-work

> NOTE: Template files do not have `%` processing enabled when processed
> through ERB. Only `<%= … %>` tags are recognized.

## Environment

I primarily use Mac OS X and Ubuntu Linux, and I use this to configure
my environment when I'm using Zsh. When I need a pure bash environment,
I will use the work bash environment. Fortunately, I am usually able to
use Zsh.

## Features

There are tons of features. One of these days, I'll document them all. 

### Ordered startup

Major startup for the Zsh environment is fairly ordered and is
controlled by the names of the files in `zsh/rc.d`.

Startup within the `.zshrc` is fairly ordered.

### Plugins

There's a plug-in system to load functionality only when the
prerequisites are present. Plug-ins are not guaranteed to load in
any particular order, but plug-ins as a whole will load last.

> NOTE: plug-ins do not currently load last. This is changing as more of
> the shell system is moving toward plug-in definitions.

## Inspiration

The basic structure was originally based on Ryan Bates's dotfile
configurations, but my own biases and influences from other example
repositories have been adopted here making regular merges impossible.

I have liberally taken inspiration and code from the following projects,
repositories and other places on the 'net that I'm not even sure of
anymore.

### ryanb/dotfiles

* https://github.com/ryanb/dotfiles

### henrik/dotfiles

* https://github.com/henrik/dotfiles

### zshkit

* https://github.com/bkerley/zshkit
* https://github.com/mattfoster/zshkit

### oh-my-zsh

* https://github.com/robbyrussell/oh-my-zsh
