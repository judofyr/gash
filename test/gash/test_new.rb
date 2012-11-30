covers 'gash'

test_class Gash do

  class_method :new do

    test "without a path defaults to the current working path" do
      repo = Gash.new
      repo.directory.assert == Dir.pwd
    end

  end

end
