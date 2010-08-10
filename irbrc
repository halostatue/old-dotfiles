#!/usr/bin/ruby

require 'irb/completion'
require 'irb/ext/save-history'

require 'rubygems'

def _init_(library)
  library = { library => library } if library.kind_of? String
  library.each_pair do |gem_name, require_name|
    begin
      gem gem_name
      require require_name
      yield if block_given?
    rescue Exception => exception
      puts "Gem #{gem_name} cannot be initialized (#{exception})."
    end
  end
end

_init_('wirble') { Wirble.init; Wirble.colorize }
_init_('boson') { Boson.start }
_init_('hirb') { extend Hirb::Console; Hirb::View.enable }
_init_('awesome_print' => 'ap')

IRB.conf[:SAVE_HISTORY] = 1000
IRB.conf[:HISTORY_FILE] = File.join(ENV['HOME'], ".irb_history")
IRB.conf[:AUTO_INDENT] = true

# IRB.conf[:PROMPT_MODE] = :SIMPLE

class Object
  # list methods which aren't in superclass
  def local_methods(obj = self)
    (obj.methods - obj.class.superclass.instance_methods).sort
  end

  # Generate the class inheritance tree, in ASCII.
  def classtree(root = self.class, options = {})
    if PLATFORM =~ /win32|mingw/
      colourise  = options[:colourise]    || false
    else
      colourise  = options[:colourise]    || true
    end
    output       = options[:output]       || $stdout

    # get children of root
    children = {}
    maxlength = root.to_s.length
    ObjectSpace.each_object(Class) do |klass|
      if (root != klass && klass.ancestors.include?(root))
        (children[klass.superclass] ||= []) << klass
        maxlength = klass.to_s.length if klass.to_s.length > maxlength
      end
    end
    maxlength += 3

    # print nice ascii class inheritance tree
    indentation = " " * 4
    (c = {}).default = ""
    if colourise
      c[:lines]       = "\033[34;1m"
      c[:dots]        = "\033[31;1m"
      c[:class_names]  = "\033[33;1m"
      c[:module_names] = "\033[32;1m"
      c[:method_names] = "\033[39;m"
    end

    rprint = proc do |current_root, prefix|
      ind_s = maxlength - current_root.to_s.length
      if options[:show_methods] # show methods (but don't show mixed in modules)
        output.puts prefix.tr('`', '|')
        #     methods = (current_root.instance_methods - (begin current_root.superclass.instance_methods; rescue NameError; []; end))
        methods = current_root.instance_methods(false).sort
        strings = methods.collect do |m|
          if children[current_root].nil?
            s = " " * maxlength
          else
            ind = " " * (maxlength - indentation.length - 1)
            s = "#{c[:lines]}#{indentation}|#{ind}"
          end

        "#{prefix.tr('`', ' ')}#{s}#{c[:dots]}:.. #{c[:method_names]}#{m.to_s}"
        end

        strings[0] = "#{prefix}#{c[:lines]}- #{c[:class_names]}#{current_root.to_s} #{c[:dots]}"
        if not methods[0].nil?
          ind = '.' * ind_s
          strings[0] << "#{ind} #{c[:method_names]}#{methods[0]}"
        end

        strings.each {|s| output.puts(s) }
      else
        s = "#{prefix}#{c[:lines]}- #{c[:class_names]}#{current_root.to_s}"
        modules = current_root.included_modules - [Kernel]
        if modules.size > 0
          ind = ' ' * ind_s
          s << "#{ind}#{c[:lines]}[ #{c[:module_names]}"
          s << modules.join("#{c[:lines]}, #{c[:module_names]}")
          s << "#{c[:lines]} ]"
        end
        output.puts(s)
      end
      if not children[current_root].nil?
        children[current_root].sort! {|a, b| a.to_s <=> b.to_s}
        children[current_root].each do |child|
          s = (child == children[current_root].last) ? '`' : '|'
          rprint[child, "#{prefix.tr('`', ' ')}#{indentation}#{c[:lines]}#{s}"]
        end
      end
    end

    rprint.call(root, "")
    nil
  end

  # Generate the class inheritance tree, in ASCII, 
  def classtree_methods(root = self.class, options = {})
    classtree(root, options.merge({:show_methods => true}))
  end
end
