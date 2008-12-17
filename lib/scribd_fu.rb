require 'attachment_fu/methods'
require 'paperclip/methods'

module ScribdFu
  # A list of content types supported by scribd.
  CONTENT_TYPES = ['application/pdf', 'image/jpeg', 'image/pjpeg',
                   'image/gif', 'image/png', 'image/x-png', 'image/jpg',
                   'application/msword', 'application/mspowerpoint',
                   'application/vnd.ms-powerpoint', 'application/excel',
                   'application/vnd.ms-excel', 'application/postscript',
                   'text/plain', 'application/rtf',
                   'application/vnd.oasis.opendocument.text',
                   'application/vnd.oasis.opendocument.presentation',
                   'application/vnd.oasis.opendocument.spreadsheet',
                   'application/vnd.sun.xml.writer',
                   'application/vnd.sun.xml.impress',
                   'application/vnd.sun.xml.calc',
    # OOXML, AKA `the MIME types from hell'. Seriously, these are long enough to
    # start their own dictionary...
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.template',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.openxmlformats-officedocument.presentationml.slideshow',
    'application/vnd.openxmlformats-officedocument.presentationml.template',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.template']

  def self.included(base)
    base.extend ActsAsScribdDocument
  end

  module ActsAsScribdDocument
    # Synonym for <tt>has_scribdable_attachment(nil)</tt>.
    def acts_as_scribd_document
      has_scribdable_attachment
    end

    # Marks the given +attribute+ as a scribdable document file. If +attribute+
    # is nil, assumes this is an Attachment_fu model and deals with the setup
    # accordingly; otherwise, assumes a +paperclip+ model and sets up scribding
    # related to the particular given attribute.
    def has_scribdable_attachment(attribute = nil)
      class_eval do
        include ScribdFu::InstanceMethods

        if attribute.nil?
          include ScribdFu::AttachmentFu::InstanceMethods
        else
          include ScribdFu::Paperclip::InstanceMethods # ignored if already done

          add_scribd_attribute attribute # class method added by above include
        end
      end
    end
  end

  module InstanceMethods
    # Sets up Scribd configuration info when this module is included.
    def self.included(base)
      base.extend ClassMethods

      mattr_reader :scribd_config, :scribd_login

      begin
        require 'rscribd'
      rescue LoadError
        raise RequiredLibraryNotFoundError.new('rscribd could not be loaded')
      end

      begin
        unless @@scribd_login
          @@scribd_config = YAML.load_file("#{RAILS_ROOT}/config/scribd.yml").symbolize_keys
          @@scribd_config = @@scribd_config[:scribd]

          # Ensure we can connect to the Service
          Scribd::API.instance.key    = @@scribd_config['key'].to_s.strip
          Scribd::API.instance.secret = @@scribd_config['secret'].to_s.strip

          @@scribd_login = Scribd::User.login @@scribd_config['user'].to_s.strip, @@scribd_config['password'].to_s.strip
        end
      rescue
        raise "config/scribd.yml file not found, or your credentials are incorrect."
      end
    end

    def access_level
      if self.respond_to?(:is_public) && self.is_public != nil
        scribd_access = self.is_public ? 'public' : 'private'
      else
        scribd_access = scribd_config['access']
      end

      scribd_access
    end
  end

  module ClassMethods
    # Sets up the scribd_options accessor, a before_destroy hook to ensure the
    # deletion of associated Scribd documents, and an after_save hook to upload
    # to scribd.
    def self.extended(base)
      base.class_inheritable_accessor :scribd_options

      base.before_destroy    :destroy_scribd_documents
      base.before_validation :upload_to_scribd
    end
  end
end
