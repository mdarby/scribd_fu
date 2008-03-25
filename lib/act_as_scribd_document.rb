module MDarby
  module Acts
    module Scribd_fu

      def self.included(base)
        base.extend ActsAsScribdObject
      end 

      module ActsAsScribdObject
        def acts_as_scribd_document(options = {})
          class_eval <<-END
          include MDarby::Acts::Scribd_fu::InstanceMethods    
          END
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods

          mattr_reader :scribd_config

          begin
            require 'rscribd'
          rescue LoadError
            raise RequiredLibraryNotFoundError.new('rscribd could not be loaded')
          end

          begin
            @@scribd_config_path = "#{RAILS_ROOT}/config/scribd.yml"
            @@scribd_config = YAML.load_file(@@scribd_config_path).symbolize_keys

            # Ensure we can connect to the Service
            Scribd::API.instance.key    = @@scribd_config[:key]
            Scribd::API.instance.secret = @@scribd_config[:secret]

            @@user = Scribd::User.login(@@scribd_config[:user], @@scribd_config[:password])
          rescue
            puts "Config file not found, or your credentials are b0rked!"
            exit
          end

          def self.scribd_user
            @scribd_user = @@user
          end
        end
        
        def get_all_documents
          @@user.documents
        end

        def get_document(id)
          @@user.find_document(id)
        end        
      end

      module ClassMethods
        # Supported Filetypes
        # doc, ppt, pps, xls, pdf, ps, odt, odp, sxw, sxi, jpg, jpeg, png, gif, txt, rtf

        @@content_types = ['image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/x-png', 'image/jpg']
        mattr_reader :content_types

        def self.extended(base)
          base.class_inheritable_accessor :scribd_options
          base.before_destroy :destroy_scribd_document
          base.after_save :upload_to_scribd
        end

        def scribd_user
          MDarby::Acts::Scribd_fu::InstanceMethods.scribd_user
        end          

        def validates_as_scribd_document
          validates_presence_of :scribd_id, :scribd_access_id
          validate              :scribd_attributes_valid?
        end

        def scribd_attributes_valid?
          [:scribd_id, :scribd_access_id].each do |attr_name|
            enum = scribd_options[attr_name]
            errors.add attr_name, ActiveRecord::Errors.default_error_messages[:inclusion] unless enum.nil? || enum.include?(send(attr_name))
          end
        end

        def scribdable?(content_type)
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
          puts "HERE!"
          unless self.scribd_id.blank?
            document = scribd_user.find_document(self.scribd_id)

            if document.destroy
              logger.info "#{Time.now.rfc2822}: Removing Scribd Object #{self.id} successful"
            else
              logger.info "#{Time.now.rfc2822}: Removing Scribd Object #{self.id} failed!"
            end
          end
        end

        def upload_to_scribd
          puts self.to_yaml
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
end