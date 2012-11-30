covers 'gash'

test_class Gash::Tree do

  method :retrieve do

    concern "tree of workiong git repository" do
      @repo = Gash.new(:branch=>'test')
      @tree = Tree.new(:parent => @repo)
    end

    test "return a Blob if the repository object is a file" do
      obj = @tree.retreive('foo.rb')
      obj.assert.is_a? == Gash::Blob
    end

    test "return a Tree if the repository object is a subdirectory" do
      obj = @tree.retrieve('bar')
      obj.assert.is_a? == Gash::Tree
    end

    test "return nil if a repository object is not found" do
      @tree.retrieve('snafu').assert == nil
    end

    test "passing lazy flag prevents the object from being loaded immediately" do
      # TODO: how do we test?
      @tree.retrieve('baz.rb', true)
    end

    test "the #[] method is an alias of #retrieve" do
      @tree['foo.rb'] == @tree.retrieve['foo.rb']
    end

    test "the #/ method is also an alias of #retrieve" do
      (@tree / 'foo.rb') == @tree.retrieve['foo.rb']
    end

  end

end
