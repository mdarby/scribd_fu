module ScribdFuHelper
  # Displays the scribd object for the attachment on the given +object+. If
  # +alt_text_or_attribute+ is given, then it will be used as the alternate text
  # for an Attachment_fu model, or as the attribute name for a Paperclip
  # model. If you want to specify alternate text for a Paperclip model, use the
  # last parameter, +alt_text_if_paperclip+.
  #
  # If you are using Paperclip, you _must_ specify +alt_text_or_attribute+ as
  # the attribute on which the scribd object exists.
  #
  # For example, using Attachment_fu:
  #  <%= display_scribd document %>
  #  <%= display_scribd document, 'You need Flash to view this document' %>
  #
  # Using Paperclip:
  #  <%= display_scribd user, :biography %>
  #  <%= display_scribd user, :biography, 'You need Flash for biographies." %>
  def display_scribd(object, alt_text_or_attribute = '', alt_text_if_paperclip = nil)
    # Resolve the right scribd ID, access key, and alt text.
    if object.respond_to?("scribd_id")
      scribd_id = object.scribd_id
      scribd_ak = object.scribd_access_key

      alt_text = alt_text_or_attribute
    else
      scribd_id = object.send "#{alt_text_or_attribute}_scribd_id"
      scribd_ak = object.send "#{alt_text_or_attribute}_scribd_access_key"

      alt_text = alt_text_if_paperclip
    end

    <<-END
      <script type=\"text/javascript\" src=\"http://www.scribd.com/javascripts/view.js\"></script>
      <div id=\"embedded_flash\">#{alt_text}</div>
      <script type=\"text/javascript\">
        var scribd_doc = scribd.Document.getDoc(#{scribd_id}, '#{scribd_ak}');
        scribd_doc.write(\"embedded_flash\");
      </script>
    END
  end
end
