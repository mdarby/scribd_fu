require 'rake'

Gem::Specification.new do |s|
  s.name     = "scribd_fu"
  s.version  = "1.2"
  s.date     = "2008-12-14"
  s.summary  = "Quick and easy interactions with Scribd's iPaper service"
  s.email    = "matt@matt-darby.com"
  s.homepage = "http://github.com/mdarby/scribd_fu/tree/master"
  s.description = "A Rails plugin that streamlines interactions with the Scribd service"
  s.has_rdoc = true
  s.authors  = ["Matt Darby"]
  s.files    = FileList['lib/**/*.rb', '*'].to_a

  s.add_dependency 'rscribd'
end
