require 'rubygems'
require 'rake'
require 'spec/rake/spectask'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "scribd_fu"
    gem.summary = %Q{A Rails gem that streamlines interactions with the Scribd service}
    gem.description = %Q{A Rails gem that streamlines interactions with the Scribd service}
    gem.email = "matt@matt-darby.com"
    gem.homepage = "http://github.com/mdarby/scribd_fu"
    gem.authors = ["Matt Darby"]
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

desc "Run all specs"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['spec/*_spec.rb']
end

desc "Run all specs with RCov"
Spec::Rake::SpecTask.new('coverage') do |t|
  t.spec_files = FileList['spec/*_spec.rb']
  t.rcov = true
end

task :test => :check_dependencies

begin
  require 'cucumber/rake/task'
  Cucumber::Rake::Task.new(:features)

  task :features => :check_dependencies
rescue LoadError
  task :features do
    abort "Cucumber is not available. In order to run features, you must: sudo gem install cucumber"
  end
end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "scribd_fu #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
