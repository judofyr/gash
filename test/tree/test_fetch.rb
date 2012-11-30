covers 'gash'

test_class Gash::Tree do

  method :fetch do

    concern "tree of workiong git repository" do
      @repo = Gash.new(:branch=>'test')
      @tree = Tree.new(:parent => @repo)
    end

    test "return a Blob if the repository object is a file" do
      obj = @tree.fetch('foo.rb')
      obj.assert.is_a? == Gash::Blob
    end

    test "return a Tree if the repository object is a subdirectory" do
      obj = @tree.fetch('bar')
      obj.assert.is_a? == Gash::Tree
    end

    test "raise an IndexError if a repository object is not found" do
      expect IndexError do
        @tree.fetch('snafu')
      end
    end

    test "return default if given instead of raising an IndexError" do
      @tree.fetch('snafu', nil).assert == nil
    end

  end

end
