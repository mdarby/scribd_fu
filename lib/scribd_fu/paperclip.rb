module ScribdFu
  module Paperclip

    module ClassMethods
    end

    module InstanceMethods

      def self.included(base)
        base.extend ClassMethods
      end

      # Find the content type of the associated file
      def get_content_type
        self.send("#{prefix}_content_type")
      end

      # Returns a URL for a thumbnail for the attached file object.
      def thumbnail_url
        begin
          (ipaper_document && ipaper_document.thumbnail_url) || attached_file.url(:thumb)
        rescue
          raise ScribdFu::ScribdFuError, "The thumbnail doesn't exist."
        end
      end

      # Returns the full filename for the given attribute. If the file is
      # stored on S3, this is a full S3 URI, while it is a full path to the
      # local file if the file is stored locally.
      def file_path
        attached_file.url =~ ScribdFu::S3 ? attached_file.url : attached_file.path
      end


      private

        # Figure out what Paperclip is calling the attached file object
        # ie. has_attached_file :attachment => "attachment"
        def prefix
          @prefix ||= self.class.column_names.detect{|c| c.ends_with?("_file_name")}.gsub("_file_name", '')
        end

        # Return the attached file object
        def attached_file
          @file ||= self.send(prefix)
        end

    end
  end

end
