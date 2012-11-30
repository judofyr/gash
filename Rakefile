gem 'rdoc'

require 'yaml'
require 'rdoc/task'

metadata = YAML.load_file('.ruby')
version  = metadata['version']

# DEPRECATED: Use gh-pages instead
#Rake::Task[:publish_docs].instance_eval do
#  @actions.clear
#  enhance do
#    sh("rsync -avc --delete doc/* judofyr@rubyforge.org:/var/www/gforge-projects/dojo/gash/")
#  end
#end

RDoc::Task.new do |rdoc|
  rdoc.generator = 'hanna'
  rdoc.main = 'README.rdoc'
  rdoc.rdoc_dir = 'web'
  rdoc.title = "Gash #{version} Documentation"
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "build gem"
task :gem do
  sh "gem build .gemspec"
end

desc "push gem to server"
task :push do
  file = Dir["*-#{version}.gem"].first
  abort "No gem!" unless file
  sh "gem push #{file}"
end

#desc "tag version"
#task :tag do
#  sh "git tag -a"
#end

desc "release package" # and tag"
task :release => [:gem, :push] do
  puts "Don't forget to tag the version!"
end

