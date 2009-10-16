require 'rake'

# $noop = true

if $noop
  class FileOps
    class << self
      def method_missing(sym, *args, &block)
        puts "FileOps.#{sym} #{args.join(', ')}"
      end
    end
  end
else
  require 'fileutils'
  FileOps = FileUtils
end

def backup_file(target)
  unless File.symlink? target
    puts "Backing up target #{File.basename(target)}..."
    FileOps.cp target, "#{target}.backup"
  end
end

def remove_file(target)
  if File.exist? target or File.symlink? target
    backup_file target
    puts "Removing target #{File.basename(target)}..."
    FileOps.rm target, :force => true
  end
end

def link_file(source, target)
  puts "Linking source #{File.basename(source)} as target #{File.basename(target)}..."
  FileOps.ln_s source, target
end

def replace_file(source, target)
  remove_file target
  link_file source, target
end

def try_replace_file(source, target = source)
  source = File.expand_path(File.join(Dir.pwd, source))
  target = File.expand_path(File.join(ENV['HOME'], target))
  replace = false

  if File.exist? target
    if $replace_all
      replace = true
    else
      print "Overwrite target #{File.basename(target)}? [yNaq] "
      case $stdin.gets.chomp
      when 'a'
        puts "Replacing all files."
        replace = $replace_all = true
      when 'y'
        replace = true
      when 'q'
        puts "Stopping."
        exit
      else
        puts "Skipping target #{File.basename(target)}..."
      end
    end
  else
    replace = true
  end

  replace_file(source, target) if replace
end

desc "Install dot files into user's home directory."
task :install do
  $replace_all = false
  Dir['*'].each do |file|
    next if %w[.gitignore Rakefile README LICENSE gitconfig.linux gitconfig.macosx].include? file
    
    try_replace_file(file, ".#{file}")
  end

  case %x(uname)
  when /Linux/i
    try_replace_file("gitconfig.linux", ".gitconfig")
  when /Darwin/i
    try_replace_file("gitconfig.macosx", ".gitconfig")
  end
end

task :default do
  Rake.application.tasks.each { |t|
    puts "rake #{t.name}  # #{t.comment}" unless t.comment.nil? or t.comment.empty?
  }
end
