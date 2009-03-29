require 'rubygems'
require 'active_record'
require 'rscribd'

ROOT       = File.join(File.dirname(__FILE__), '..')
RAILS_ROOT = ROOT

$LOAD_PATH << File.join(ROOT, 'lib')
$LOAD_PATH << File.join(ROOT, 'lib', 'scribd_fu')

require File.join(ROOT, 'lib', 'scribd_fu.rb')

ENV['RAILS_ENV'] ||= 'test'

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.establish_connection(config[ENV['RAILS_ENV'] || 'test'])

def rebuild_model options = {}
  ActiveRecord::Base.connection.create_table :documents, :force => true do |table|
    table.column :ipaper_id, :string
    table.column :ipaper_access_key, :string
    table.column :content_type, :string
  end
  
  ActiveRecord::Base.connection.create_table :attachments, :force => true do |table|
    table.column :ipaper_id, :string
    table.column :ipaper_access_key, :string
    table.column :attachment_content_type, :string
  end

  Object.send(:remove_const, "Document") rescue nil
  Object.const_set("Document", Class.new(ActiveRecord::Base))
  
  Object.send(:remove_const, "Attachment") rescue nil
  Object.const_set("Attachment", Class.new(ActiveRecord::Base))  
end

Spec::Runner.configure do |config|
end


# EOF