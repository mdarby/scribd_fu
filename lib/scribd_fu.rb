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
    @@content_types = ['application/pdf', 'application/msword', 'application/mspowerpoint', 'application/vnd.ms-powerpoint',
                        'application/excel', 'application/vnd.ms-excel', 'application/postscript', 'text/plain', 'application/rtf',
												'application/vnd.oasis.opendocument.text', 'vnd.oasis.opendocument.presentation',
                        'application/vnd.sun.xml.writer', 'application/vnd.sun.xml.impress', 
												'application/vnd.oasis.opendocument.spreadsheet', 'application/vnd.sun.xml.calc']

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
          Scribd::API.instance.key    = @@scribd_config[:scribd]['key'].to_s.strip
          Scribd::API.instance.secret = @@scribd_config[:scribd]['secret'].to_s.strip

          @@scribd_login = Scribd::User.login @@scribd_config[:scribd]['user'].to_s.strip, @@scribd_config[:scribd]['password'].to_s.strip
        end
      rescue
        raise "config/scribd.yml file not found, or your credentials are incorrect."
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
      if scribd_document
        if scribd_document.destroy
          logger.info "[Scribd_fu] #{Time.now.rfc2822}: Removing Object #{id} successful"
        else
          logger.info "[Scribd_fu] #{Time.now.rfc2822}: Removing Object #{id} failed!"
        end
      end
    end

    def access_level
      if self.respond_to?(:is_public) && self.is_public != nil
        scribd_access = self.is_public ? 'public' : 'private'
      else
        scribd_access = scribd_config[:scribd]['access']
      end
      
      scribd_access
    end
    
    def final_path      
      if scribd_config[:scribd]['storage'].eql?('s3')
        file_path = s3_url
      else
        file_path = full_filename
      end
    
      file_path
    end
    
    def upload_to_scribd
      if scribdable? and self.scribd_id.blank?
        
        if resource = scribd_login.upload(:file => "#{final_path}", :access => access_level)
          logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object #{id} successfully uploaded for conversion to iPaper."

          self.scribd_id         = resource.doc_id
          self.scribd_access_key = resource.access_key

          save
        else
          logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object #{id} upload failed!"
        end
      end
    end

    # Sample of use in a view:
    # image_tag(@attachment).thumbnail_url, :alt => @attachment.name)
    def thumbnail_url
      scribd_document ? scribd_document.thumbnail_url : nil
    end

    # Sample of use in a controller:
    # render :inline => @attachment.thumbnail_file, :content_type => 'image/jpeg'
    def thumbnail_file
      scribd_document ? open(scribd_document.thumbnail_url).read : nil
    end

    # Responds true if the conversion is complete -- note that this gives no
    # indication as to whether the conversion had an error or was succesful,
    # just that the conversion completed.
    #
    # Note that this method still returns false if the model does not refer to a
    # valid document.  scribd_attributes_valid? should be used to determine the
    # validity of the document.
    def conversion_complete?
      scribd_document && scribd_document.conversion_status != 'PROCESSING'
    end

    # Responds true if the document has been converted.
    #
    # Note that this method still returns false if the model does not refer to a
    # valid document.  scribd_attributes_valid? should be used to determine the
    # validity of the document.
    def conversion_successful?
      scribd_document && scribd_document.conversion_status =~ /^DISPLAYABLE|DONE$/
    end

    # Responds true if there was a conversion error while converting
    # to iPaper.
    #
    # Note that this method still returns false if the model does not refer to a
    # valid document.  scribd_attributes_valid? should be used to determine the
    # validity of the document.
    def conversion_error?
      scribd_document && scribd_document.conversion_status == 'ERROR'
    end

    # Responds the Scribd::Document associated with this model, or nil if it
    # does not exist.
    def scribd_document
      @scribd_document ||= scribd_login.find_document(scribd_id)
    rescue Scribd::ResponseError # at minimum, the document was not found
      nil
    end
  end

end
