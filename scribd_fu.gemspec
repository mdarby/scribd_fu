Gem::Specification.new do |s|
  s.name     = "scribd_fu"
  s.version  = "1.2"
  s.date     = "2008-12-16"
  s.summary  = "Quick and easy interactions with Scribd's iPaper service"
  s.email    = "matt@matt-darby.com"
  s.homepage = "http://github.com/mdarby/scribd_fu/tree/master"
  s.description = "A Rails plugin that streamlines interactions with the Scribd service"
  s.has_rdoc = false
  s.authors  = ["Matt Darby"]
  s.files    = ['init.rb', 'install.rb', 'uninstall.rb', 'MIT-LICENSE', 'Rakefile',
                'README',  'lib/scribd_fu.rb', 'lib/scribd_fu_helper.rb',
                'lib/attachment_fu/methods.rb', 'lib/paperclip/methods.rb',
                'rails/init.rb', 'scribd_fu.gemspec',
                'generators/scribd_config/scribd_config_generator.rb',
                'generators/scribd_config/templates/scribd.yml']
  s.add_dependency 'rscribd'
end
