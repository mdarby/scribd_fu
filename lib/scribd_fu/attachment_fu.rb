module ScribdFu
  module AttachmentFu

    module ClassMethods
    end

    module InstanceMethods

      def self.included(base)
        base.extend ClassMethods
      end

      # Returns a URL for a thumbnail for this model's attachment.
      def thumbnail_url
        (ipaper_document && ipaper_document.thumbnail_url) || public_filename(:thumb)
      end

      # Returns the content type for this model's attachment.
      def get_content_type
        self.content_type
      end

      # Yields the correct path to the file, either the local filename or the S3 URL.
      def file_path
        if ScribdFu::amazon_based?(public_filename)
          path = public_filename
        else
          path = "#{RAILS_ROOT}/public#{public_filename}"
        end

        ScribdFu::strip_cache_string(path)
      end
    end

  end
end
