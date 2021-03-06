require 'spec_helper'

# This runs ActiveModel::Lint tests
# See:
#   https://gist.github.com/1892874
describe Methodology do
  subject { ::Methodology.new }

  # FIXME, right now ActiveModel lint fails because to_params returns the filename even if
  # persisted? is false.
  # The problem is we're using an spurious Methodology object (whose backend is a Note and
  # not a file on disk, like when we go admin::templates::methodologies) in the
  # MethodologiesController
  # We need to address this by making Methodology a 1st class citizen of
  # the app.
  #
  # A failing spec is a good reminder of this
  it_behaves_like "ActiveModel" unless ENV['CI']

  before(:each) do
    Methodology.stub(:pwd) { Pathname.new('tmp/templates/methodologies') }
  end
  after(:all) do
    FileUtils.rm_rf('tmp/templates')
  end

  describe "#destroy" do
    it "deletes file from disk on destroy" do
      mt = Methodology.new(:content => 'FooBar', :filename => 'mt_test')
      mt.save

      filename = Methodology.pwd.join('mt_test.xml')
      File.exists?(filename).should be_true
      mt.should respond_to('destroy')
      mt.should respond_to('delete')
      mt.destroy
      File.exists?(filename).should be_false
    end

    it "destroy() works even if the file doesn't exist any more or never existed" do
      mt = Methodology.new(:filename => 'foobar')
      lambda { mt.destroy }.should_not raise_error

      filename = Methodology.pwd.join('foobar.xml')
      FileUtils.mkdir_p(Methodology.pwd)
      File.open(filename,'w'){ |f| f<<'barfoo' }

      mt = Methodology.from_file(filename)
      mt.content.should eq('barfoo')
      File.delete(filename)

      lambda { mt.destroy }.should_not raise_error
    end
  end

  describe "#name=" do
    it "updates content when setting :name attribute" do
      methodology = Methodology.from_file('spec/fixtures/files/methodologies/webapp.xml')
      methodology.name = 'Foo'
      methodology.name.should eq('Foo')
      methodology.content.should include('Foo')
    end
  end

  describe "#save" do
    it "creates the base dir if it doesn't exist when saving" do
      FileUtils.rm_rf(Methodology.pwd) if File.exists?(Methodology.pwd)

      Timecop.freeze(Time.now)

      mt = Methodology.new(:content => 'Simple methodology content: *kapow*!')
      mt.save.should be_true

      new_methodology = Methodology.pwd.join("auto_#{Time.now.to_i}.xml")
      File.exists?(Methodology.pwd).should be_true
      File.exists?(new_methodology).should be_true
      File.read(new_methodology).should eq('Simple methodology content: *kapow*!')
      File.delete(new_methodology)

      Timecop.return
    end


    it "saves the template contents when saving the instance" do
      mt = Methodology.new(:content => 'FooBar', :filename => 'mt_test')
      mt.save.should be_true
      filename = Methodology.pwd.join('mt_test.xml')
      File.exists?(filename).should be_true
      File.read(filename).should eq('FooBar')
      File.delete(filename)
    end
  end

  describe "#to_html_anchor" do
    it "discards non-alphanumeric characters in the name" do
      methodology = Methodology.new(filename: 'mt_test')

      methodology.name = 'Foo [Bar]'
      expect(methodology.to_html_anchor).not_to match(/[^0-9a-z\-\_]/i)

      methodology.name = '(Foo) Bar'
      expect(methodology.to_html_anchor).not_to match(/[^0-9a-z\-\_]/i)

      methodology.name = 'Foo.Bar'
      expect(methodology.to_html_anchor).not_to match(/[^0-9a-z\-\_]/i)
    end
  end

  context "working with tasks" do
    it "defines a #tasks method that returns the list of tasks across sections" do
      methodology = Methodology.from_file('spec/fixtures/files/methodologies/webapp.xml')
      expect(methodology).to respond_to(:tasks)
      expect(methodology.tasks).to respond_to(:count)
      expect(methodology.tasks.count).to eq(3)
    end

    it "defines a #completed_tasks method that returns the list of tasks already completed" do
      methodology = Methodology.from_file('spec/fixtures/files/methodologies/webapp.xml')
      expect(methodology).to respond_to(:completed_tasks)
      expect(methodology.completed_tasks).to respond_to(:count)
      expect(methodology.completed_tasks.count).to eq(0)

      # Where is my developer pride? You let me know when you find it. Ugg!
      methodology.doc.at_xpath('//task').set_attribute('checked', 'checked')
      expect(methodology.completed_tasks.count).to eq(1)
    end
  end
end
