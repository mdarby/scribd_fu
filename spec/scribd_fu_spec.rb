require File.join(File.dirname(__FILE__), %w[spec_helper])

describe "ScribdFu" do

  describe "with incorrect Scribd credentials" do
    before do
      Scribd::User.stub!(:login).and_raise(Scribd::ResponseError)
    end

    it "should throw an error" do
      lambda { ScribdFu::scribd_user }.should raise_error(ScribdFu::ScribdFuError)
    end
  end

  describe "that is missing a config file" do
    before do
      File.should_receive(:file?).with("#{RAILS_ROOT}/config/scribd_fu.yml").and_return(false)
    end

    it "should raise an error" do
      lambda { ScribdFu::config }.should raise_error(ScribdFu::ScribdFuError)
    end

  end

end

describe "An AttachmentFu model" do
  before do
    rebuild_model
  end

  describe "that is configured for ScribdFu" do
    before do
      config = YAML.load_file("spec/scribd_fu.yml")
      File.stub!(:file?).with(ScribdFu::ConfigPath).and_return(true)
      YAML.stub!(:load_file).and_return(config)

      Document.class_eval do
        has_ipaper_and_uses 'AttachmentFu'
      end

      @document = Document.new
    end

    describe "with correct credentials" do
      before do
        @scribd_user = mock("scribd_user")
        Scribd::User.stub!(:login).and_return(@scribd_user)
      end

      describe "that was just created" do
        before do
          @document.attributes = {:ipaper_id => nil, :ipaper_access_key => nil, :content_type => "application/pdf"}
          @document.stub!(:public_filename => "/path/to/somewhere")
        end

        describe "and is scribdable?" do
          before do
            @document.stub!(:scribdable? => true)
          end

          describe "and uploading to Scribd succeeded" do
            before do
              @scribd_response = mock('scribd_response', :doc_id => "doc_id", :access_key => "access_key")
              @scribd_user.should_receive(:upload).and_return(@scribd_response)
            end

            it "should update the Scribd-centric attributes" do
              @document.should_receive(:update_attributes).with({:ipaper_id => 'doc_id', :ipaper_access_key => 'access_key'})
              @document.save
            end

          end

          describe "and uploading to Scribd failed" do
            before do
              @scribd_user.stub!(:upload).and_raise(StandardError)
            end

            it "should throw an error" do
              lambda { ScribdFu::upload(@document, 'private') }.should raise_error(ScribdFu::ScribdFuUploadError)
            end

          end

        end

        describe "and is not scribdable?" do
          before do
            @document.stub!(:scribdable? => false)
          end

          it "should not upload to Scribd" do
            ScribdFu.should_not_receive(:upload)
            @document.save
          end

        end

      end

      describe "that was just updated" do
        before do
          @document.stub!(:ipaper_id => 'doc_id')
        end

        it "should not reupload to Scribd" do
          @scribd_user.should_not_receive(:upload)
          @document.save
        end

      end

      describe "that is about to be destroyed" do
        before do
          @ipaper_document = mock("ipaper_document")
          ScribdFu.stub!(:load_ipaper_document).and_return(@ipaper_document)
        end

        it "should destroy the ipaper document" do
          ScribdFu.should_receive(:destroy).with(@ipaper_document)
          @document.destroy
        end

      end

    end

  end

end

describe "A Paperclip model" do
  before do
    rebuild_model
  end

  describe "that is configured for ScribdFu" do
    before do
      config = YAML.load_file("spec/scribd_fu.yml")
      File.stub!(:file?).with(ScribdFu::ConfigPath).and_return(true)
      YAML.stub!(:load_file).and_return(config)

      Attachment.class_eval do
        has_ipaper_and_uses 'Paperclip'
      end

      @attached_file = mock("attached_file", :url => "http://test.com/path/to/somewhere", :path => "/path/to/somewhere")

      @attachment = Attachment.new
      @attachment.stub!(:prefix).and_return("attachment")
      @attachment.stub!(:attached_file).and_return(@attached_file)
    end

    describe "with correct credentials" do
      before do
        @scribd_user = mock("scribd_user")
        Scribd::User.stub!(:login).and_return(@scribd_user)
      end

      describe "that was just created" do
        before do
          @attachment.attributes = {:ipaper_id => nil, :ipaper_access_key => nil, :attachment_content_type => "application/pdf"}
          @attachment.stub!(:file_path => "/path/to/somewhere")
        end

        describe "and is scribdable?" do
          before do
            @attachment.stub!(:scribdable? => true)
          end

          describe "and uploading to Scribd succeeded" do
            before do
              @scribd_response = mock('scribd_response', :doc_id => "doc_id", :access_key => "access_key")
              @scribd_user.should_receive(:upload).and_return(@scribd_response)
            end

            it "should update the Scribd-centric attributes" do
              @attachment.should_receive(:update_attributes).with({:ipaper_id => 'doc_id', :ipaper_access_key => 'access_key'})
              @attachment.save
            end

          end

          describe "and uploading to Scribd failed" do
            before do
              @scribd_user.stub!(:upload).and_raise(StandardError)
            end

            it "should throw an error" do
              lambda { ScribdFu::upload(@attachment, 'private') }.should raise_error(ScribdFu::ScribdFuUploadError)
            end

          end

        end

        describe "and is not scribdable?" do
          before do
            @attachment.stub!(:scribdable? => false)
          end

          it "should not upload to Scribd" do
            ScribdFu.should_not_receive(:upload)
            @attachment.save
          end

        end

      end

      describe "that was just updated" do
        before do
          @attachment.stub!(:ipaper_id => 'doc_id')
        end

        it "should not reupload to Scribd" do
          @scribd_user.should_not_receive(:upload)
          @attachment.save
        end

      end

      describe "that is about to be destroyed" do
        before do
          @ipaper_document = mock("ipaper_document")
          ScribdFu.stub!(:load_ipaper_document).and_return(@ipaper_document)
        end

        it "should destroy the ipaper document" do
          ScribdFu.should_receive(:destroy).with(@ipaper_document)
          @attachment.destroy
        end

      end

    end

  end

end

describe "Viewing an iPaper document" do
  before do
    rebuild_model
    
    config = YAML.load_file("spec/scribd_fu.yml")
    File.stub!(:file?).with(ScribdFu::ConfigPath).and_return(true)
    YAML.stub!(:load_file).and_return(config)
    
    Document.class_eval do
      has_ipaper_and_uses 'AttachmentFu'
    end
    
    @document = Document.new
    @document.attributes = {:ipaper_id => 'doc_id', :ipaper_access_key => 'access_key'}
  end
  
  it "should return this HTML by default" do
    @document.display_ipaper.should == "        <script type=\"text/javascript\" src=\"http://www.scribd.com/javascripts/view.js\"></script>\n        <div id=\"embedded_flash\"></div>\n        <script type=\"text/javascript\">\n          var scribd_doc = scribd.Document.getDoc(doc_id, 'access_key');\n          \n          scribd_doc.write(\"embedded_flash\");\n        </script>\n"
  end
  
  it "should allow custom Javascript params" do
    options = {:height => 100, :width => 100}
    @document.display_ipaper(options).should == "        <script type=\"text/javascript\" src=\"http://www.scribd.com/javascripts/view.js\"></script>\n        <div id=\"embedded_flash\"></div>\n        <script type=\"text/javascript\">\n          var scribd_doc = scribd.Document.getDoc(doc_id, 'access_key');\n          scribd_doc.addParam('width', '100');\nscribd_doc.addParam('height', '100');\n          scribd_doc.write(\"embedded_flash\");\n        </script>\n"
  end
  
  it "should allow not allow crazy custom Javascript params" do
    options = {:some_dumb_setting => 100, :width => 100}
    @document.display_ipaper(options).should == "        <script type=\"text/javascript\" src=\"http://www.scribd.com/javascripts/view.js\"></script>\n        <div id=\"embedded_flash\"></div>\n        <script type=\"text/javascript\">\n          var scribd_doc = scribd.Document.getDoc(doc_id, 'access_key');\n          scribd_doc.addParam('width', '100');\n          scribd_doc.write(\"embedded_flash\");\n        </script>\n"
  end
  
end