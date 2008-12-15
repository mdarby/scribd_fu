require 'ftools'

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

      def scribd_attributes
        read_inheritable_attribute :scribd_attributes
      end

      private
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
          document = scribd_document_for(self["#{attribute}_scribd_id"])

          unless document.nil?
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
            with_file_path_for(attribute) do |filename|
              if resource = scribd_login.upload(:file   => filename,
                                                :access => access_level)
                self.send("#{attribute}_scribd_id=",         resource.doc_id)
                self.send("#{attribute}_scribd_access_key=", resource.access_key)

                logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object " +
                            "#{id}##{attribute} successfully uploaded " +
                            "for conversion to iPaper."
              else
                logger.info "[Scribd_fu] #{Time.now.rfc2822}: Object " +
                            "#{id}##{attribute} upload failed!"

                false # cancel the save
              end
            end
          end
        end
      end

      # Returns a URL for a thumbnail for the specified +attribute+ attachment.
      #
      # If Scribd does not provide a thumbnail URL, then Paperclip's thumbnail
      # is fallen back on by returning the value of
      # <tt>attribute.url(:thumb)</tt>.
      #
      # Sample use in a view:
      #  <%= image_tag(@attachment.thumbnail_url, :alt => @attachment.name) %>
      def thumbnail_url(attribute)
        doc = scribd_document_for(attribute)

        (doc && doc.thumbnail_url) or self.send(attribute).url(:thumb)
      end

      # Returns the actual image data of a thumbnail for the specified
      # +attribute+ attachment.
      #
      # If Scribd does not have a thumbnail for this file, then
      # Paperclip's thumbnanil is fallen back on by returning the file from
      # <tt>attribute.to_file(:thumb)</tt>.
      #
      # Sample use in a controller:
      #  render :inline => @attachment.thumbnail_file,
      #         :content_type => 'image/jpeg'
      def thumbnail_file(attribute)
        doc = scribd_document_for(attribute)

        if doc && doc.thumbnail_url
          open(doc.thumbnail_url).read
        else
          send(attribute).to_file(:thumb).open { |f| f.read }
        end
      rescue Errno::ENOENT, NoMethodError # file not found or nil thumb file
        nil
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

        # Yields the correct path to the file for the attachment in
        # +attribute+, either the local filename or the S3 URL.
        #
        # This method creates a temporary file of the correct filename  for the
        # attachment in +attribute+ if necessary, so as to be able to give
        # scribd the right filename. The file is destroyed when the passed block
        # ends.
        def with_file_path_for(attribute, &block) # :yields: full_file_path
          attachment = attachment_for(attribute)

          if attachment.respond_to?(:s3)
             yield attachment.url
          elsif File.exists?(attachment.path)
            yield attachment.path
          else # file hasn't been saved, use a tempfile
            temp_rename = File.join(Dir.tmpdir, attachment.original_filename)
            File.copy(attachment.to_file.path, temp_rename)

            yield temp_rename
          end
        ensure
          temp_rename && File.unlink(temp_rename) # always delete this
        end
    end
  end
end
