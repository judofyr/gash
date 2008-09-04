require 'echoe'
require 'hanna/rdoctask'

Echoe.new('gash') do |p|
  p.project = "dojo"
  p.author = "Magnus Holm"
  p.email = "judofyr@gmail.com"
  p.summary = "Git + Hash"
  p.url = "http://dojo.rubyforge.org/gash/"
  p.rdoc_options += ["--main", "Gash", "--title", "Gash"]
end

Rake::Task[:publish_docs].instance_eval do
  @actions.clear
  enhance do
    sh("rsync -avc --delete doc/* judofyr@rubyforge.org:/var/www/gforge-projects/dojo/gash/")
  end
end