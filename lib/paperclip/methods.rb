module ScribdFu
  module Paperclip
    module ClassMethods
      # Adds validations to the current model to check that its attachment is
      # scribdable.
      def validates_as_scribd_document
        validates_presence_of :scribd_id, :scribd_access_id, :content_type
        validate              :scribd_attributes_valid?
      end
    end

    module InstanceMethods
      def self.included(base)
        base.extend ClassMethods
      end

      def scribd_attributes_valid?
        [:scribd_id, :scribd_access_id].each do |attr_name|
          enum = scribd_options[attr_name]
          errors.add attr_name, ActiveRecord::Errors.default_error_messages[:inclusion] unless enum.nil? || enum.include?(send(attr_name))
        end
      end

      def scribdable?
        ScribdFu::SCRIBD_CONTENT_TYPES.include?(content_type)
      end

      def scribd_id=(id)
        write_attribute :scribd_id, id.to_s.strip
      end

      def scribd_access_key=(key)
        write_attribute :scribd_access_key, key.to_s.strip
      end

      def destroy_scribd_documents
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
          if resource = scribd_login.upload(:file => "#{full_filename}", :access => scribd_config[:scribd]['access'])
            logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object #{id} successfully uploaded for conversion to iPaper."

            self.scribd_id         = resource.doc_id
            self.scribd_access_key = resource.access_key

            save
          else
            logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object #{id} upload failed!"
          end
        end
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
end
