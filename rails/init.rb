require 'scribd_fu'
require 'scribd_fu_helper'

ActiveRecord::Base.send(:include, ScribdFu)
ActionView::Base.send(:include, ScribdFuHelper)

RAILS_DEFAULT_LOGGER.debug "** [Scribd_fu] loaded"
