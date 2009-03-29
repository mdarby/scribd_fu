class ScribdFuGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.file 'scribd_fu.yml', 'config/scribd_fu.yml', :collision => :skip
    end
  end
end
