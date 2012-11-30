cover 'gash'

test_class Gash::Tree do

  method :to_hash do

    concern "tree of workiong git repository" do
      @repo = Gash.new(:branch=>'test')
      @tree = Tree.new(:parent => @repo)
    end

    test "convert to ordinary hash object" do
      hash = @tree.to_hash
      hash.class.assert == Hash
      # TODO: add some additional detailed assertions
    end

  end

end
