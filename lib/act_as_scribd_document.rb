module MDarby
  module Acts
    
    @@content_types = ['image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/x-png', 'image/jpg']
    mattr_reader :content_types
    
    # Supported Filetypes
    # doc, ppt, pps, xls, pdf, ps, odt, odp, sxw, sxi, jpg, jpeg, png, gif, txt, rtf
    
    module Scribdfu
    
      class ConfigFileNotFoundError < StandardError; end
      
      def self.included(base)
        base.extend ActsAsScribdDocument
      end 

      module ActsAsScribdDocument
        def acts_as_scribd_document(options = {})
          class_eval <<-END
          include MDarby::Acts::Scribdfu::InstanceMethods    
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
            @@scribd_config_path = RAILS_ROOT + '/config/scribd.yml'
            @@scribd_config = YAML.load_file(@@scribd_config_path).symbolize_keys
          rescue
            raise ConfigFileNotFoundError.new('File %s not found' % @@scribd_config_path)
          end
        end

        module ClassMethods
          
          delegate :content_types, :to => MDarby::Acts
          
          def validates_as_scribd_document
            validates_presence_of :scribd_id, :scribd_access_id
            validate              :scribd_attributes_valid?
          end

          # validates the size and content_type attributes according to the current model's options
          def scribd_attributes_valid?
            [:size, :content_type].each do |attr_name|
              enum = scribd_options[attr_name]
              errors.add attr_name, ActiveRecord::Errors.default_error_messages[:inclusion] unless enum.nil? || enum.include?(send(attr_name))
            end
          end

          
          # self.class?
          

          # Returns true or false if the given content type is recognized as an Scribdable Document.
          def scribdable?(content_type)
            content_types.include?(content_type)
          end

          def self.extended(base)
            base.class_inheritable_accessor :scribd_options
            base.before_destroy :destroy_scribd_document
            base.after_save :upload_to_scribd
          end
          
          def scribd_id=(id)
            write_attribute :scribd_id, id.to_s.strip
          end

          def scribd_access_key=(key)
            write_attribute :scribd_access_key, key.to_s.strip
          end
          
          def destroy_scribd_document
            if self.scribd_id
              user = Scribd::User.login 'XXX', 'XXXXX'
              document = user.find_document(self.scribd_id)

              unless document.destroy
                logger.info "#{Time.now.rfc2822}: Removing Scribd Document #{self.id} failed!"
              end
            end
          end
          
          def upload_to_scribd
            if doc = Scribd::Document.create(:file => "#{document.public_filename}", :access => "private")
              logger.info "#{Time.now.rfc2822}: Document #{document.id} successfully converted to iPaper."

              document.scribd_id         = doc.doc_id
              document.scribd_access_key = doc.access_key

              if document.save!
                logger.info "#{Time.now.rfc2822}: Document #{document.id} saved after being converted to iPaper."

                # Upload to S3 via the S3_worker
                logger.info "#{Time.now.rfc2822}: Scheduling Document #{document.id} for S3 upload"
                document.upload_to_s3
              else
                logger.info "#{Time.now.rfc2822}: Document #{document.id} failed to save after being converted to iPaper!"
              end

            else
              logger.info "#{Time.now.rfc2822}: Document #{document.id} iPaper conversion failed..."
            end
          end
          
        end 

      end 
    end
  end
end