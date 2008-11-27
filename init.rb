require 'scribd_fu'
require 'scribd_fu_helper'
ActiveRecord::Base.send(:include, ScribdFu)
ActionView::Base.send(:include, ScribdFuHelper)
