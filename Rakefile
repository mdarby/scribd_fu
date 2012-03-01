#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rspec/core/rake_task"

desc "Run all specs"
RSpec::Core::RakeTask.new :spec


desc "Run all specs with RCov"
RSpec::Core::RakeTask.new(:coverage) do |t|
  t.rcov = true
end

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "scribd_fu #{ScribdFu::VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
