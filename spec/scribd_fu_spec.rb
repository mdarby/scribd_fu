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
      File.should_receive(:file?).with("config/scribd_fu.yml").and_return(false)
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
            @document.stub!(:update_attributes)
          end

          describe "and has spaces in the filename" do
            it "should sanitize the file path" do
              res = mock('response', :doc_id => 1, :access_key => "ASDF")
              @scribd_user.should_receive(:upload).with(:file => "./some%20filename%20with%20spaces", :access => 'access').and_return(res)
              ScribdFu::upload(@document, "some filename with spaces")
            end

          end

          context "and is destined for CloudFront" do
            before do
              @document.stub!(:public_filename => "http://a9.cloudfront.net/something.pdf?0000000000")
            end

            it "should return the CloudFront URL, not the local filesystem path" do
              @document.file_path.should == "http://a9.cloudfront.net/something.pdf"
            end

          end

          context "and is destined for S3" do
            before do
              @document.stub!(:public_filename => "http://s3.amazonaws.com/something.pdf")
            end

            it "should return the AWS URL, not the local filesystem path" do
              @document.file_path.should == "http://s3.amazonaws.com/something.pdf"
            end

          end

          describe "and has a ipaper_my_user_id" do
            before do
              @document.stub!(:ipaper_my_user_id => '1234')
            end

            it "should pass the parameter when uploading" do
              filename = File.join(File.dirname(__FILE__), 'sample.txt')
              Scribd::API.instance.should_receive(:send_request).with('docs.upload', hash_including({:access => 'access', :my_user_id => '1234'})).and_return(REXML::Document.new("<rsp stat='ok'><doc_id>1</doc_id><access_key>ASDF</access_key></rsp>"))
              Scribd::API.instance.should_receive(:send_request).with('docs.changeSettings', {:doc_ids => '1', :my_user_id => '1234'})
              ScribdFu::upload(@document, filename)
            end
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

          it "should not error out when deleted" do
            lambda {@document.destroy}.should_not raise_error(ScribdFu::ScribdFuError)
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

      @attached_file = mock("attached_file", :url => "http://test.com/path/to/somewhere", :path => "/path/to/somewhere", :options => {})

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
        end

        describe "and is scribdable?" do
          before do
            @attachment.stub!(:scribdable? => true)
          end

          describe "and has special characters in the filename" do
            before do
              @attached_file.stub!(:path => "/path/to/somewhere with spaces.pdf")
              @attachment.stub!(:update_attributes)
            end

            it "should sanitize the file path spaces" do
              res = mock('response', :doc_id => 1, :access_key => "ASDF")
              @scribd_user.should_receive(:upload).with(:file => "/path/to/somewhere%20with%20spaces.pdf", :access => 'access').and_return(res)
              ScribdFu::upload(@attachment, "/path/to/somewhere with spaces.pdf")
            end

            it "should sanitize the file path accented characters" do
              res = mock('response', :doc_id => 1, :access_key => "ASDF")
              @scribd_user.should_receive(:upload).with(:file => "/path/to/new%20l%C3%ADder.pdf",
                                                        :access => 'access').and_return(res)
              ScribdFu::upload(@attachment, "/path/to/new líder.pdf")
            end

          end

          context "and it was uploaded to S3" do
            before do
              @attached_file.stub!(:url => "http://s3.amazonaws.com/path/to/somewhere.pdf?0000000000")
              @attached_file.stub!(:options => {:storage => :s3})
            end

            it "should strip the trailing cache string before sending to Scribd" do
              @attachment.file_path.should == "http://s3.amazonaws.com/path/to/somewhere.pdf"
            end
          end

          context "and is destined for CloudFront" do
            before do
              @attached_file.stub!(:url => "http://a9.cloudfront.net/something.pdf?0000000000")
              @attached_file.stub!(:options => {:storage => :s3})
            end

            it "should return the CloudFront URL, not the local filesystem path" do
              @attachment.file_path.should == "http://a9.cloudfront.net/something.pdf"
            end

          end

          describe "and uploading to Scribd succeeded" do
            before do
              @scribd_response = mock('scribd_response', :doc_id => "doc_id", :access_key => "access_key")
              @scribd_user.should_receive(:upload).and_return(@scribd_response)
            end

            it "should update the Scribd-centric attributes" do
              @attachment.should_receive(:update_attributes).with({
                :ipaper_id         => 'doc_id',
                :ipaper_access_key => 'access_key'
              })
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
    @document.stub!(:to_param).and_return(5)
  end

  it "should return this HTML by default" do
    @document.display_ipaper.gsub(/\s{2,}/, "").should == "<script type=\"text/javascript\" src=\"http://www.scribd.com/javascripts/view.js\"></script><div id=\"embedded_flash\"></div><script type=\"text/javascript\">var scribd_doc = scribd.Document.getDoc(doc_id, 'access_key');scribd_doc.write(\"embedded_flash\");</script>\n"
  end

  it "should allow custom alt text" do
    @document.display_ipaper(:alt => "something").should =~ /.*<div id="embedded_flash">something<\/div>.*/
  end

  it "should allow custom Javascript params" do
    options = {:height => 100, :width => 100}

    @document.display_ipaper(options).should =~ /.*scribd_doc\.addParam\('height', '100'\);.*/
    @document.display_ipaper(options).should =~ /.*scribd_doc\.addParam\('width', '100'\);.*/
  end

  it "should allow not allow crazy custom Javascript params" do
    options = {:some_dumb_setting => 100, :width => 100}

    @document.display_ipaper(options).should =~ /.*scribd_doc\.addParam\('width', '100'\);.*/
    @document.display_ipaper(options).should_not =~ /.*scribd_doc\.addParam\('some_dumb_setting', '100'\);.*/
  end

  it "should send booleans as booleans" do
    options = {:hide_disabled_buttons => true}
    @document.display_ipaper(options).should =~ /.*scribd_doc\.addParam\('hide_disabled_buttons', true\);.*/
  end

  it "should support passing in an id for the div" do
    options = {:id => 'abc123'}
    @document.display_ipaper(options).should =~ /id="scribd_abc123"/
  end

  it 'should put the ar to_param value as the embedded_id for the id param on the iframe if the id option is not passed' do
    @document.display_ipaper.should =~ /id="scribd_5"/
  end

  it 'should support passing view_mode as an option' do
    options = {:view_mode => 'slideshow'}
    @document.display_ipaper(options).should =~ /view_mode=slideshow/
  end

  it 'should default to list if not passing view_mode as an option' do
    @document.display_ipaper.should =~ /view_mode=list/
  end
end

