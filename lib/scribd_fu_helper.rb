module ScribdFuHelper
  # Displays the scribd object for the attachment on the given +object+.
  #
  # If you are using Paperclip, you must also specify the +attribute+ on
  # which the scribd object exists.
  def display_scribd(object, attribute = nil)
    out = '<script type="text/javascript" src="http://www.scribd.com/javascripts/view.js"></script>'
    out = out + '<div id="embedded_flash"></div>'
    out = out + '<script type="text/javascript">'

    if attribute.nil?
      scribd_id = object.send "#{attribute}_scribd_id"
      scribd_ak = object.send "#{attribute}_scribd_access_key"
      out = out + "var scribd_doc = scribd.Document.getDoc(#{scribd_id}, '#{scribd_ak}');"
    else
      out = out + "var scribd_doc = scribd.Document.getDoc(#{object.scribd_id}, '#{object.scribd_access_key}');"
    end

    out = out + "scribd_doc.write('embedded_flash');"
    out = out + "</script>"

    out
  end
end
