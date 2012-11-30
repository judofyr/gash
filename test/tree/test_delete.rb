cover 'gash'

test_class Gash::Tree do

  method :delete do

    concern "tree of workiong git repository" do
      @repo = Gash.new(:branch=>'test')
      @tree = Tree.new(:parent => @repo)
    end

    test "removes an object from the tree" do
      @tree.delete('foo.rb')
      @tree['foo.rb'].assert.nil?
    end

  end

end
