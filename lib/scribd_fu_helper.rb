module ScribdFuHelper

  def display_scribd(object)
    out = '<script type="text/javascript" src="http://www.scribd.com/javascripts/view.js"></script>'
    out = out + '<div id="embedded_flash"></div>'
    out = out + '<script type="text/javascript">'
    out = out + "var scribd_doc = scribd.Document.getDoc(#{object.scribd_id}, '#{object.scribd_access_key}');"
    out = out +	"scribd_doc.write('embedded_flash');"
    out = out + "</script>"

    out
  end
end
