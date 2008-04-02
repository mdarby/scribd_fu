module Scribd_fu
  
  def self.included(base)
    base.extend ActsAsScribdObject
  end 

  module ActsAsScribdObject
    def acts_as_scribd_document(options = {})
      class_eval <<-END
        include Scribd_fu::InstanceMethods    
      END
    end
  end
  
  module ClassMethods
    def self.extended(base)
      base.class_inheritable_accessor :scribd_options
      base.before_destroy :destroy_scribd_document
      base.after_save :upload_to_scribd
    end

    def validates_as_scribd_document
      validates_presence_of :scribd_id, :scribd_access_id, :content_type
      validate              :scribd_attributes_valid?
    end
  end
  
  module InstanceMethods
    @@content_types = ['application/pdf', 'image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/x-png', 'image/jpg', 'application/msword', 'application/mspowerpoint', 
                        'application/excel', 'application/postscript', 'text/plain', 'application/rtf', 'application/vnd.oasis.opendocument.text', 'vnd.oasis.opendocument.presentation',
                        'application/vnd.sun.xml.writer', 'application/vnd.sun.xml.impress']
                        
    mattr_reader :content_types

    def self.included(base)
      base.extend ClassMethods
      
      mattr_reader :scribd_config, :scribd_login

      begin
        require 'rscribd'
      rescue LoadError
        raise RequiredLibraryNotFoundError.new('rscribd could not be loaded')
      end

      begin
        unless @@scribd_login
          @@scribd_config = YAML.load_file("#{RAILS_ROOT}/config/scribd.yml").symbolize_keys

          # Ensure we can connect to the Service
          Scribd::API.instance.key    = @@scribd_config[:key].to_s.strip
          Scribd::API.instance.secret = @@scribd_config[:secret].to_s.strip

          @@scribd_login = Scribd::User.login @@scribd_config[:user].strip, @@scribd_config[:password].strip
        end
      rescue
        puts "Config file not found, or your credentials are b0rked!"
        exit
      end
    end   

    def scribd_attributes_valid?
      [:scribd_id, :scribd_access_id].each do |attr_name|
        enum = scribd_options[attr_name]
        errors.add attr_name, ActiveRecord::Errors.default_error_messages[:inclusion] unless enum.nil? || enum.include?(send(attr_name))
      end
    end

    def scribdable?
      content_types.include?(content_type)
    end

    def scribd_id=(id)
      write_attribute :scribd_id, id.to_s.strip
    end

    def scribd_access_key=(key)
      write_attribute :scribd_access_key, key.to_s.strip
    end

    def destroy_scribd_document
      unless scribd_id.blank?
        document = scribd_login.find_document(scribd_id)

        if document.destroy
          logger.info "[Scribd_fu] #{Time.now.rfc2822}: Removing Object #{id} successful"
        else
          logger.info "[Scribd_fu] #{Time.now.rfc2822}: Removing Object #{id} failed!"
        end
      end
    end

    def upload_to_scribd
      if scribdable? and self.scribd_id.blank?
        if resource = scribd_login.upload(:file => "#{full_filename}", :access => scribd_config[:access])
          logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object #{id} successfully converted to iPaper."
    
          self.scribd_id         = resource.doc_id
          self.scribd_access_key = resource.access_key
    
          save
        else
          logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object #{id} iPaper conversion failed!"
        end
      end
    end
  end

end