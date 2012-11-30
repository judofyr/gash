covers 'gash'

test_class Gash::Tree do

  method :store do

    concern "tree of workiong git repository" do
      @repo = Gash.new(:branch=>'test')
      @tree = Tree.new(:parent => @repo)
    end

    test "create a Blob if the object is a string" do
      obj = @tree.store('story.txt', "Once upon a time...")
      obj.assert.is_a? == Gash::Blob
    end

    test "create a Tree if the object is a hash" do
      hsh = {
        'rabbit.txt' => "Rabbit fell.",
        'alice.txt'  => "Alice fell."
      }
      obj = @tree.store('hole', hsh)
      obj.assert.is_a? == Gash::Tree

      @tree['hole'].assert == obj
      @tree['hole']['alice.txt'].assert == "Alice fell."
    end

    test "the #[]= method is an alias of #store" do
      # TODO:
    end

  end

end
