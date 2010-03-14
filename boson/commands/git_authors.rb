module GitAuthors
  def git_authors
    `git shortlog -s -n --no-merges`.split("\n").each do |person|
      puts "* #{person.gsub(/\d/, '').strip}"
    end
  end
end
