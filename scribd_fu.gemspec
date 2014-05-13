# -*- encoding: utf-8 -*-
require File.expand_path('../lib/scribd_fu/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Matt Darby"]
  gem.email         = ["matt@matt-darby.com"]
  gem.description   = %q{A Rails gem that streamlines interactions with the Scribd service}
  gem.summary       = %q{A Rails gem that streamlines interactions with the Scribd service}
  gem.homepage      = "http://github.com/mdarby/scribd_fu"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "scribd_fu"
  gem.require_paths = ["lib"]
  gem.version       = ScribdFu::VERSION

  gem.add_runtime_dependency "rscribd"

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rails"
  gem.add_development_dependency "sqlite3"
end
