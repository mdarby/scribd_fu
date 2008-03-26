module MDarby # :nodoc:
  module Scribd_fu # :nodoc:
    
    def self.included(base)
      base.extend ActsAsScribdObject
    end 

    module ActsAsScribdObject
      def acts_as_scribd_document(options = {})
        class_eval <<-END
          include MDarby::Scribd_fu::InstanceMethods    
        END
      end
    end
    
    module InstanceMethods
      @@content_types = ['application/pdf', 'image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/x-png', 'image/jpg', 'application/msword', 'application/mspowerpoint', 
                          'application/excel', 'application/postscript', 'text/plain', 'application/rtf', 'application/vnd.oasis.opendocument.text', 'vnd.oasis.opendocument.presentation',
                          'application/vnd.sun.xml.writer', 'application/vnd.sun.xml.impress']
                          
      mattr_reader :content_types

      def self.included(base)
        base.extend ClassMethods
        
        mattr_reader :scribd_config, :scribd_user

        begin
          require 'rscribd'
        rescue LoadError
          raise RequiredLibraryNotFoundError.new('rscribd could not be loaded')
        end

        begin
          @@scribd_config_path = "#{RAILS_ROOT}/config/scribd.yml"
          @@scribd_config = YAML.load_file(@@scribd_config_path).symbolize_keys

          # Ensure we can connect to the Service
          Scribd::API.instance.key    = @@scribd_config[:key].strip
          Scribd::API.instance.secret = @@scribd_config[:secret].strip

          @@scribd_login = Scribd::User.login @@scribd_config[:user].strip, @@scribd_config[:password].strip
        rescue
          puts "Config file not found, or your credentials are b0rked!"
          exit
        end
      end
      
      def self.scribd_user
        @scribd_user = scribd_login
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

        def get_all_documents          
          #MDarby::Scribd_fu.scribd_user.documents
          #MDarby::Scribd_fu.scribd_login.documents
          #scribd_login.documents
          #scribd_user.documents
          #@scribd_user.documents
          #@scribd_login.documents
          #@@scribd_user.documents
          #@@scribd_login.documents
        end

        def get_document
          @@user.find_document(scribd_id)
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

      def show
      end

      def edit(options = {})
      end

      def destroy_scribd_document
        unless scribd_id.blank?
          document = scribd_user.find_document(self.scribd_id)
          puts document.to_yaml
          
          # if document.destroy
          #   logger.info "#{Time.now.rfc2822}: Removing Scribd Object #{self.id} successful"
          # else
          #   logger.info "#{Time.now.rfc2822}: Removing Scribd Object #{self.id} failed!"
          # end
        end
      end

      def upload_to_scribd
        if scribdable?
          puts "We can upload"
        else
          puts "Nothing doing"
        end
        
      #   if scribdable?
      #     if document = Scribd::Object.create(:file => "#{self.public_filename}", :access => scribd_config[:access])
      #       logger.info "#{Time.now.rfc2822}: Object #{self.id} successfully converted to iPaper."
      # 
      #       self.scribd_id         = document.doc_id
      #       self.scribd_access_key = document.access_key
      # 
      #       if save!
      #         logger.info "#{Time.now.rfc2822}: Object #{self.id} saved after being converted to iPaper."
      #       else
      #         logger.info "#{Time.now.rfc2822}: Object #{self.id} failed to save after being converted to iPaper!"
      #       end
      #     else
      #       logger.info "#{Time.now.rfc2822}: Object #{self.id} iPaper conversion failed..."
      #     end
      #   else
      #     logger.info "#{Time.now.rfc2822}: Object #{self.id} is not Scribdable!"
      #   end
      end
    end
  end
end
