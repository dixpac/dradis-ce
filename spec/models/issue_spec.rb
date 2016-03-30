require 'spec_helper'

describe Issue do

  let(:issue) { Issue.new }

  it "is assigned to the Category.issue category" do
    node = create(:node)
    # use a block because we can't mass-assign 'node':
    issue = Issue.new { |i| i.node = node }
    issue.should be_valid()
    issue.save
    issue.category.should eq(Category.issue)
  end

  it "affects many nodes through :evidence" do
    issue = create(:issue)
    issue.affected.should be_empty

    host = create(:node, label: '10.0.0.1', type_id: Node::Types::HOST)
    host.evidence.create(author: 'rspec', issue_id: issue.id, content: "#[EvidenceBlock1]#\nThis apache is old!")

    issue.reload
    issue.affected.should_not be_empty
    issue.affected.first.should eq(host)
  end

  it { should have_many(:evidence).dependent(:destroy) }
  it { should have_many(:activities) }

  describe "on delete" do
    before do
      @issue = create(:issue, node: create(:node_with_project))
      @activities = create_list(:activity, 2, trackable: @issue)
      @issue.destroy
    end

    it "doesn't delete or nullify any associated Activities" do
      # We want to keep records of actions performed on a issue even after it's
      # been deleted.
      @activities.each do |activity|
        activity.reload
        expect(activity.trackable).to be_nil
        expect(activity.trackable_id).to eq @issue.id
        expect(activity.trackable_type).to eq "Issue"
      end
    end

  end


  describe "#title" do
    subject { issue.title }

    context "when the issue has a #[Title]# field" do
      before { issue.text = "#[Title]#\nMy Title" }
      it { should eq "My Title" }

      specify "#title? returns true" do
        expect(issue.title?).to be_true
      end
    end

    context "when the issue does not have a #[Title]# field" do
      before { issue.text = "#[Not The Title]#\nMy Title" }
      it { should eq "This issue doesn't provide a #[Title]# field" }

      specify "#title? returns false" do
        expect(issue.title?).to be_false
      end
    end
  end

  describe "#set_field" do
    it "sets a field and updates 'body'" do
      issue.text = "#[Title]#\nSomething"
      issue.set_field("Title", "New title")
      expect(issue.fields["Title"]).to eq "New title"
      expect(issue.text).to eq "#[Title]#\nNew title"
    end
  end


  describe "#activities" do
    it "returns the issue's activities" do
      # this requires some hackery, because by default it won't work because
      # Issue and Note don't use proper single-table inheritance :(
      node  = create(:node_with_project)
      issue = create(:issue, node: node, project: node.project)
      activities = create_list(:activity, 2, trackable: issue)

      # Sanity check that all trackable types are 'Issue', not 'Note'
      expect(activities.map(&:trackable_type).uniq).to eq ["Issue"]

      expect(issue.activities).to be_an(ActiveRecord::Relation)
      expect(issue.activities).to eq activities
    end
  end

  describe ".search" do
    it "filters issues by text matching search term" do
      first = create(:issue, text: "First issue")
      second = create(:issue, text: "Second issue")
      term = "first"

      results = Issue.search(term: term)

      expect(results.size).to eq 1
      expect(results.first.text).to eq first.text
    end

    it "returns list of matches order by updated_at desc" do
      first = create(:issue, text: "First issue")
      second = create(:issue, text: "Second issue")
      term = "issue"

      results = Issue.search(term: term)

      expect(results.map(&:text)).to eq [second.text, first.text]
    end

    it "behaves as case insensitive search" do
      issue = create(:issue, text: "Issue")
      term = "ISSuE"

      results = Issue.search(term: term)

      expect(results.size).to eq 1
      expect(results.first.text).to eq issue.text
    end
  end


  # NOTE: the idea of having an Affected field appended to the automagically was
  # to allow the Affected field content control in AdvancedWordExport to work in
  # the same way the other fields do. However, this introduces a cascading SQL
  # problem every time we access any field, so we've moved the functionality to
  # retrieve the affected hosts to:
  #   AdvancedWordExport::Processors::Ooxml::Processor::populate_field - fields.rb#257
  #
  #it "provides access to the list of Affected fields as another note field" do
  #  issue = create(:issue)
  #  node1 = create(:node)
  #  node1.evidence.create(:author => 'rspec', :issue_id => issue.id, :content => 'Foo')
  #  node2 = create(:node)
  #  node2.evidence.create(:author => 'rspec', :issue_id => issue.id, :content => 'Bar')
  #  issue.reload
  #  issue.fields['Affected'].should eq([node1, node2].collect(&:label).to_sentence)
  #end
  #it "The Affected field contains each host only once" do
  #  issue = create(:issue)
  #  node1 = create(:node)
  #  node1.evidence.create(:author => 'rspec', :issue_id => issue.id, :content => 'Foo')
  #  node1.evidence.create(:author => 'rspec', :issue_id => issue.id, :content => 'Bar')
  #  node2 = create(:node)
  #  node2.evidence.create(:author => 'rspec', :issue_id => issue.id, :content => 'BarFar')
  #  issue.reload
  #  issue.fields['Affected'].should eq([node1, node2].collect(&:label).to_sentence)
  #end
end
