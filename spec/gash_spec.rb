describe Gash do
  let(:gash) { Gash.new(path) }

  it "starts with an empty directory" do
    gash.should be_empty
  end

  it "should not be empty after a file has been added" do
    gash["File"] = "data"
    gash.should_not be_empty
  end

  it "commits files when #commit are applied to gash object" do
    gash["File"] = "data"
    hash = gash.commit("My commit message")
    list_files(hash).should include("File")
  end

  it "can override files" do
    gash["File"] = "data"
    hash = gash.commit("My commit message")
    list_files(hash).should include("File")
    gash["File"] = "other"
    hash = gash.commit("My commit message 2")
    content.should match(/other/)
  end

  it "can create a tree" do
    gash["my-folder/file"] = "content"
    hash = gash.commit("My commit message")
    content.should match(/content/)
    folder("my-folder").should_not be_nil
    folder("non-existing").should be_nil
  end
end