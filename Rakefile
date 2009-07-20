require 'rake'

desc "install the dot files into user's home directory"
task :install do
  $replace_all = false
  Dir['*'].each do |file|
    next if %w[Rakefile README LICENSE gitconfig.linux gitconfig.macosx].include? file
    
    try_replace_or_link_file(file, ".#{file}")
  end
  case %x(uname)
  when /Linux/i
    try_replace_or_link_file(".gitconfig.linux", ".gitconfig")
  when /Darwin/i
    try_replace_or_link_file(".gitconfig.macosx", ".gitconfig")
  end
end

def try_replace_or_link_file(file, as_file = file)
  if File.exist?(File.join(ENV['HOME'], as_file))
    if $replace_all
      replace_file(file, as_file)
    else
      print "overwrite ~/#{as_file}? [ynaq] "
      case $stdin.gets.chomp
      when 'a'
        $replace_all = true
        replace_file(file, as_file)
      when 'y'
        replace_file(file, as_file)
      when 'q'
        exit
      else
        puts "skipping ~/#{as_file}"
      end
    end
  else
      link_file(file, as_file)
  end
end

def replace_file(file, as_file = file)
  system %Q{rm "$HOME/#{as_file}"}
  link_file(file, as_file)
end

def link_file(file, as_file)
  puts "linking ~/#{as_file}"
  system %Q{ln -s "$PWD/#{file}" "$HOME/#{as_file}"}
end
