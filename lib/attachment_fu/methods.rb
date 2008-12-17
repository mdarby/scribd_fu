require 'ftools'

module ScribdFu
  module AttachmentFu
    module ClassMethods
      # Adds validations to the current model to check that its attachment is
      # scribdable.
      def validates_as_scribd_document
        validates_presence_of :scribd_id, :scribd_access_key, :content_type
        validate :scribdable?
      end
    end

    module InstanceMethods
      def self.included(base)
        base.extend ClassMethods
      end

      # Checks whether the attachment is scribdable. This boils down to a check
      # to ensure that the contents of the attachment are of a content type that
      # scribd can understand.
      def scribdable?
        ScribdFu::CONTENT_TYPES.include?(content_type)
      end

      def scribd_id=(id)
        write_attribute :scribd_id, id.to_s.strip
      end

      def scribd_access_key=(key)
        write_attribute :scribd_access_key, key.to_s.strip
      end

      # Destroys the scribd document for this record. This is called
      # +before_destroy+, as set up by ScribdFu::ClassMethods#extended.
      #
      # Also available as destroy_scribd_document, which makes more sense in
      # terms of pluralization for external calls.
      def destroy_scribd_documents
        unless scribd_document.nil?
          if scribd_document.destroy
            logger.info "[Scribd_fu] #{Time.now.rfc2822}: Removing Object #{id} successful"
          else
            logger.info "[Scribd_fu] #{Time.now.rfc2822}: Removing Object #{id} failed!"
          end
        end
      end
      alias_method :destroy_scribd_document, :destroy_scribd_documents

      # Uploads the attachment to scribd for processing.. This is called
      # +before_validation+, as set up by ScribdFu::ClassMethods#extended.
      def upload_to_scribd
        if scribdable? and self.scribd_id.blank?
          with_file_path do |file_path|
            if resource = scribd_login.upload(:file => "#{file_path}",
                                              :access => access_level)
              logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object #{id} successfully uploaded for conversion to iPaper."

              self.scribd_id         = resource.doc_id
              self.scribd_access_key = resource.access_key

              save
            else
              logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object #{id} upload failed!"
            end
          end
        end
      end

      # Returns a URL for a thumbnail for this model's attachment.
      #
      # If Scribd does not provide a thumbnail URL, then Attachment_fu's
      # thumbnail is fallen back on by returning the value of
      # <tt>public_filename(:thumb)</tt>.
      #
      # Sample use in a view:
      #  <%= image_tag(@attachment .thumbnail_url, :alt => @attachment.name) %>
      def thumbnail_url
        (scribd_document && scribd_document.thumbnail_url) or
          public_filename(:thumb)
      end

      # Returns the actual image data of a thumbnail for this model's
      # attachment.
      #
      # If Scribd does not have a thumbnail for this file, then Attachment_fu's
      # thumbnanil is fallen back on by returning the file at
      # <tt>full_filename(:thumb)</tt>.
      #
      # Sample use in a controller:
      #  render :inline => @attachment.thumbnail_file,
      #         :content_type => 'image/jpeg'
      def thumbnail_file
        path = (scribd_document && scribd_document.thumbnail_url) ||
                  full_filename(:thumb)

        open(path).read
      rescue Errno::ENOENT
        nil
      end

      # Yields the correct path to the file, either the local filename or the
      # S3 URL.
      #
      # This method creates a temporary file of the correct filename if
      # necessary, so as to be able to give scribd the right filename. The file
      # is destroyed when the passed block ends.
      def with_file_path(&block) # :yields: full_file_path
        # TODO We can probably do this using respond_to?
        if scribd_config['storage'].eql?('s3')
           yield s3_url
        elsif save_attachment? # file hasn't been saved, use the temp file
          temp_rename = File.join(Dir.tmpdir, filename)
          File.copy(temp_path, temp_rename)

          yield temp_rename
        else
          yield full_filename
        end
      ensure
        temp_rename && File.unlink(temp_rename) # always delete this
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
