describe Gash do
  let(:gash) { Gash.new(path) }

  it "starts with an empty directory" do
    gash.should be_empty
  end
end