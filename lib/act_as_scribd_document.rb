module MDarby
  module Acts
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
            raise RequiredLibraryNotFoundError.new('config/rscribd.yml could not be loaded')
          end

          begin
            @@scribd_config_path = RAILS_ROOT + '/config/scribd.yml'
            @@scribd_config = YAML.load_file(@@scribd_config_path)[RAILS_ENV].symbolize_keys
          rescue
            raise ConfigFileNotFoundError.new('File %s not found' % @@scribd_config_path)
          end
        end

        module ClassMethods
          
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

          # Returns true or false if the given content type is recognized as an Scribdable Document.
          def scribdable?(content_type)
            content_types.include?(content_type)
          end

          def self.extended(base)
            base.class_inheritable_accessor :scribd_options
            base.before_destroy :destroy_scribd_document
            base.after_save :upload_to_scribd
          end
          
          def destroy_scribd_document
            
          end
          
          def upload_to_scribd
            
          end
          
        end 

      end 
    end
  end
end