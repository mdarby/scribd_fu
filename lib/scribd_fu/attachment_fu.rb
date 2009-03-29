module ScribdFu
  module AttachmentFu

    module ClassMethods
    end

    module InstanceMethods
      
      def self.included(base)
        base.extend ClassMethods
      end

      # Returns a URL for a thumbnail for this model's attachment.
      #
      # If Scribd does not provide a thumbnail URL, then Attachment_fu's
      # thumbnail is fallen back on by returning the value of
      # <tt>public_filename(:thumb)</tt>.
      #
      # Sample use in a view:
      #  <%= image_tag(@attachment.thumbnail_url, :alt => @attachment.name) %>
      def thumbnail_url
        (ipaper_document && ipaper_document.thumbnail_url) || public_filename(:thumb)
      end

      def get_content_type
        self.content_type
      end

      # Yields the correct path to the file, either the local filename or the S3 URL.
      def file_path
        public_filename
      end
    end
  
  end
end
