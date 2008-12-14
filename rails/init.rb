require 'scribd_fu'
require 'scribd_fu_helper'

ActiveRecord::Base.send(:include, Scribd_fu)
ActionView::Base.send(:include, Scribd_fu_Helper)

RAILS_DEFAULT_LOGGER.debug "** [Scribd_fu] loaded"