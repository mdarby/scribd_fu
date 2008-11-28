module ScribdFu
  module Paperclip
    module ClassMethods
      # Adds validations to the current model to check that the attachment at
      # +attribute+ is scribdable. If +attribute+ is nil, then all attachments
      # that have been marked as scribdable are validated.
      #
      # Note that all calls to has_scribdable_attachment should be made before
      # calling validates_attachment_scribdability with a nil parameter;
      # otherwise, only those that have been created already will be validated.
      def validates_attachment_scribdability(attribute = nil)
        attributes = attribute.nil? ? scribd_attributes : [attribute]

        attributes.each do |attribute|
          validates_presence_of "#{attribute}_scribd_id",
                                "#{attribute}_scribd_access_key",
                                "#{attribute}_content_type"
          validates_attachment_content_type attribute,
            :content_type => ScribdFu::CONTENT_TYPES
        end
      end

      # Adds the given +attribute+ to the list of attributes that are uploaded
      # to scribd.
      #
      # Note that a scribd attribute should not be added if it is not a
      # Paperclip attachment attribute.
      def add_scribd_attribute(attribute)
        write_inheritable_attribute :scribd_attributes, [] if scribd_attributes.nil?

        scribd_attributes << attribute

        setup_scribd_attribute(attribute)
      end

      private
        def scribd_attributes
          read_inheritable_attribute :scribd_attributes
        end

        # Sets up methods needed for the given +attribute+ to be scribdable.
        def setup_scribd_attribute(attribute)
          define_method("#{attribute}_scribd_id=") do |id|
            write_attribute "#{attribute}_scribd_id", id.to_s.strip
          end

          define_method("#{attribute}_scribd_access_key=") do |key|
            write_attribute "#{attribute}_scribd_access_key", key.to_s.strip
          end
        end
    end

    module InstanceMethods
      def self.included(base)
        base.extend ClassMethods
      end

      # Checks whether the given attribute is scribdable. This boils down to a
      # check to ensure that the contents of the attribute are of a content type
      # that scribd can understand.
      def scribdable?(attribute)
        ScribdFu::CONTENT_TYPES.include?(self["#{attribute}_content_type"])
      end

      # Destroys all scribd documents for this record. This is called
      # +before_destroy+, as set up by ScribdFu::ClassMethods#extended.
      def destroy_scribd_documents
        self.class.scribd_attributes.each do |attribute|
          scribd_id = self["#{attribute}_scribd_id"]

          unless scribd_id.blank?
            document = scribd_login.find_document(scribd_id)

            if document.destroy
              logger.info "[Scribd_fu] #{Time.now.rfc2822}: Removing Object #{id}##{attribute} successful"
            else
              logger.info "[Scribd_fu] #{Time.now.rfc2822}: Removing Object #{id}##{attribute} failed!"
            end
          end
        end
      end

      # Uploads all scribdable attributes to scribd for processing. This is
      # called +before_validation+, as set up by
      # ScribdFu::ClassMethods#extended.
      def upload_to_scribd
        self.class.scribd_attributes.each do |attribute|
          scribd_id = self["#{attribute}_scribd_id"]

          if scribdable?(attribute) and scribd_id.blank?
            filename = full_filename_for(attribute)

            if resource = scribd_login.upload(:file => "#{filename}",
                                              :access => scribd_config['access'])
              logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object #{id}##{attribute} successfully uploaded for conversion to iPaper."

              self.send("#{attribute}_scribd_id=",         resource.doc_id)
              self.send("#{attribute}_scribd_access_key=", resource.access_key)
            else
              logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object #{id}##{attribute} upload failed!"

              false # cancel the save
            end
          end
        end
      end

      # Responds true if the conversion is complete for the given +attribute+ --
      # note that this gives no indication as to whether the conversion had an
      # error or was succesful, just that the conversion completed. See
      # <tt>conversion_successful?</tt> for that information.
      #
      # Note also that this method still returns false if the model does not
      # refer to a valid document.  scribd_attributes_valid? should be used to
      # determine the validity of the document.
      def conversion_complete?(attribute)
        doc = scribd_document_for(attribute)

        doc && doc.conversion_status != 'PROCESSING'
      end

      # Responds true if the document for the given +attribute+ has been
      # converted successfully. This *will* respond false if the conversion has
      # failed.
      #
      # Note that this method still returns false if the model does not refer to a
      # valid document. <tt>scribd_attributes_valid?</tt> should be used to
      # determine the validity of the document.
      def conversion_successful?(attribute)
        doc = scribd_document_for(attribute)

        doc && doc.conversion_status =~ /^DISPLAYABLE|DONE$/
      end

      # Responds true if there was a conversion error while converting the given
      # +attribute+ to iPaper.
      #
      # Note that this method still returns false if the model does not refer to a
      # valid document. <tt>scribd_attributes_valid?</tt> should be used to
      # determine the validity of the document.
      def conversion_error?(attribute)
        doc = scribd_document_for(attribute)

        doc && doc.conversion_status == 'ERROR'
      end

      # Responds the Scribd::Document associated with the given +attribute+, or
      # nil if it does not exist.
      def scribd_document_for(attribute)
        scribd_documents[attribute] ||= scribd_login.find_document(self["#{attribute}_scribd_id"])
      rescue Scribd::ResponseError # at minimum, the document was not found
        nil
      end

      private
        def scribd_documents
          @scribd_documents ||= HashWithIndifferentAccess.new
        end

        # Returns the full filename for the given attribute. If the file is
        # stored on S3, this is a full S3 URI, while it is a full path to the
        # local file if the file is stored locally.
        def full_filename_for(attribute)
          filename = attachment_for(attribute).path
        end
    end
  end
end
