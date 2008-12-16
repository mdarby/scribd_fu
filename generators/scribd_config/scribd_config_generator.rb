class ScribdConfigGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.file 'scribd.yml', 'config/scribd.yml'
    end
  end
end
