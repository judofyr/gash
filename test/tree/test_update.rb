cover 'gash'

test_class Gash::Tree do

  method :update do

    concern "tree of workiong git repository" do
      @repo = Gash.new(:branch=>'test')
      @tree = Tree.new(:parent => @repo)
    end

    test "update takes another hash object and update the tree" do
      hsh = {
        'rabbit.txt' => "Rabbit fell.",
        'alice.txt'  => "Alice fell."
      }
      @tree.update(hsh)

      @tree['rabbit.txt'].assert == "Rabbit fell."
      @tree['alice.txt'].assert == "Alice fell."
    end

  end

end
