module Scribd_fu_Helper
  
  def display_scribd(object, alt_text = '')
    <<-END
      <script type=\"text/javascript\" src=\"http://www.scribd.com/javascripts/view.js\"></script>
      <div id=\"embedded_flash\">#{alt_text}</div>
      <script type=\"text/javascript\">
        var scribd_doc = scribd.Document.getDoc(#{object.scribd_id}, '#{object.scribd_access_key}');
        scribd_doc.write(\"embedded_flash\");
      </script>
    END
  end
  
end