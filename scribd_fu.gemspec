Gem::Specification.new do |s|
  s.name     = "scribd_fu"
  s.version  = "2.0.4"
  s.date     = "2009-04-12"
  s.summary  = "Quick and easy interactions with Scribd's iPaper service"
  s.email    = "matt@matt-darby.com"
  s.homepage = "http://github.com/mdarby/scribd_fu/tree/master"
  s.description = "A Rails plugin that streamlines interactions with the Scribd service"
  s.has_rdoc = false
  s.authors  = ["Matt Darby"]
  s.files    = [
    'MIT-LICENSE',
    'README.textile',
    'generators/scribd_fu',
    'generators/scribd_fu/scribd_fu_generator.rb',
    'generators/scribd_fu/templates',
    'generators/scribd_fu/templates/scribd_fu.yml',
    'init.rb',
    'lib/scribd_fu',
    'lib/scribd_fu/attachment_fu.rb',
    'lib/scribd_fu/paperclip.rb',
    'lib/scribd_fu.rb',
    'scribd_fu.gemspec',
    'spec/database.yml',
    'spec/scribd_fu.yml',
    'spec/scribd_fu_spec.rb',
    'spec/spec_helper.rb'
  ]
  s.add_dependency 'rscribd'
end