describe Gash do
  let(:gash) { Gash.new(path) }

  it "starts with an empty directory" do
    gash.should be_empty
  end

  it "should not be empty after a file has been added" do
    gash["File"] = "data"
    gash.should_not be_empty
  end
end