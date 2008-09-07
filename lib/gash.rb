require 'delegate'

# == What is Gash?
#
# * Gash lets you access a Git-repo as a Hash.
# * Gash only cares about the data, not the commits.
# * Gash only cares about the _latest_ data.
# * Gash can commit.
# * Gash doesn't touch your working directory
# * Gash will automatically create branches if they don't exists.
# * Gash only loads what it needs, so it handles large repos well.
#
# == How do you use it?
#
#   gash = Gash.new
#   gash["README"] = "new content"
#   gash.commit("Some changes...")
#
# It's also important to remember that a Gash is simply a Tree, so you can
# also call those methods.
#
# <strong>See also</strong>: #new, #commit, Tree
#
# == Limitation
#
# The only Hash-like features which currently works is #[] and #[]=,
# so don't try #merge or something like that.
class Gash < SimpleDelegator
  module Errors
    # This error is raised when the Git-command fails.
    class Git < StandardError; end
    class NoGitRepo < StandardError; end
  end
  
  # Some common methods used by both Tree and Blob.
  module Helpers
    attr_accessor :sha1, :mode, :parent
    
    # Sets the accessors using a Hash:
    #
    #   tree = Gash::Tree.new(:sha1 => "some thing", :mode => "some thing",
    #                         :parent => "some parent")
    #   tree.sha1 == "some thing"
    #   tree.mode == "some thing"
    #   tree.parent == "some parent"
    def initialize(opts = {})
      opts.each do |key, value|
        send("#{key}=", value)
      end
    end
    
    # Checks if this is a Blob.
    def blob?; self.class == Gash::Blob end
    # Checks if this is a Tree.
    def tree?; self.class == Gash::Tree end
    # Checks if this object has been changed (since last commit).
    def changed?; !@sha1 end
    # Mark this, and all parents as changed.
    def changed!; @sha1 = nil;parent.changed! if parent end
    # Returns the Gash-object (top-parent).
    def gash; parent.gash if parent end
    
    # Converts the +value+ to a Tree or a Blob, using some rules:
    # 
    # == If +value+ is already a Tree or a Blob:
    # 
    # * If +value+ comes from another repo, we load it and return a deep copy.
    # * If +value+ got no parent, we simply return the same tree.
    # * If +value+'s parent is +self+, we also return the same tree.
    # * If +value+'s parent is something else, we return a duplicated tree.
    #
    # == If it's something else:
    #
    # * If +value+ is a Hash, we create a Tree from it.
    # * If it's not any of the former rules, we turn it into a string and create a Blob from it. 
    def normalize(value)
      case value
      when Tree, Blob, Gash
        if value.parent && value.parent != self
          if (g = value.gash) && self.gash == g
            value.dup
          else
            normalize(value.tree? ? value.to_hash : value.to_s)
          end
        else
          value
        end
      when Hash
        Tree[value]
      else
        Blob.new(:content => value.to_s)
      end
    end
  end
  
  # A Tree is a Hash which can store other instances of Tree and Blob.
  #
  # <strong>See also</strong>: Helpers, Blob
  class Tree < Hash
    include Helpers
    
    def self.[](*val)
      new.merge!(Hash[*val])
    end
    
    # Retrieves the _value_ stored as +key+:
    #
    #   tree["FILE"] == the file
    #   tree["DIR/FILE"] == tree["DIR"]["FILE"] = another file
    #
    # It will automatically call the +load!+-method in order to load
    # it from the repo. Set +lazy+ to +true+ if this is not what you want:
    #
    #   blob = tree["FILE", true] == #<Blob:1234...>
    #   # do some other stuff...
    #   blob.laod! # Load it now!
    def [](key, lazy = nil)
      ret = if key.include?("/")
        key, rest = key.split("/", 2)
        value = super(key)
        return if value.nil?
        value[rest]
      else
        super(key)
      end
    ensure
      ret.load! if ret.respond_to?(:load!) && !lazy
    end
    alias / []
    
    # Stores the given _value_:
    #
    #   tree["FILE"] = "Content"
    #
    # Unless it's already a Tree or a Blob, it will be converted to a Blob,
    # and the parent will _always_ be set to +self+.
    #
    #   tree["FILE"] = "Content"
    #     # is the same as:
    #   tree["FILE"] = Gash::Blob.new(:content => "Content", :parent => tree)
    #
    # It will also mark the object as changed (using <code>Helpers#changed!</code>).
    # Set +not_changed+ to +true+ if this is not what you want.
    # 
    # (If you give it three arguments, then the second one will act as
    # +not_changed+, not the third):
    #
    #   tree["FILE", true] = "Test"
    #   tree["FILE"].changed? # => false
    def []=(key, value, not_changed = nil)
      key, value, not_changed = if not_changed.nil?
        [key, value]
      else
        [key, not_changed, value]
      end
      
      if key.include?("/")
        keys = key.split("/")
        name = keys.pop
        keys.inject(self) do |memo, i|
          memo[i] = Tree.new(:parent => self) unless memo.include?(i)
          memo[i, true]
        end[name, not_changed] = value
      else
        value = normalize(value)
        value.parent = self
        super(key, value)
      end
    ensure
      self.changed! unless not_changed
    end
    
    def to_hash
      inject({}) do |memo, (key, value)|
        memo[key] = value.respond_to?(:to_hash) ? value.to_hash : value.to_s
        memo
      end
    end
    
    def merge(hash)
      tree = self.dup
      tree.merge!(hash)
    end
    
    def merge!(hash)
      hash.each do |key, value|
        self[key] = value
      end
      self
    end
    alias update merge!
    
    def replace(hash)
      if hash.is_a?(Gash::Tree)
        super
      else
        clear
        merge!(hash)
      end
    end
  end
  
  # A Blob represent a string:
  #
  #   blob = Gash::Blob.new(:content => "Some content")
  #   blob # => "Some content"
  #
  # == Using SHA1
  #
  # However, if you provide a SHA1 (and have a parent which is connected to
  # a Gash-object) it will then load the content from the repo when needed:
  #
  #   blob = Gash::Blob.new(:sha1 => "1234" * 10, :parent => gash_OR_tree_connected_to_gash)
  #   blob        # => #<Blob:1234123412341234123412341234123412341234>
  #   blob.upcase # It's loaded when needed
  #   #blob.load! # or forced with #load!
  #   blob        # => "Content of the blob"
  #
  # Tree#[]= automatically sets the parent to itself, so you don't need to
  # provide it then:
  #
  #   tree["FILE"] = Gash::Blob.new(:sha1 => a_sha1)
  #
  # <strong>See also</strong>: Helpers, Tree
  class Blob < Delegator
    include Helpers, Comparable
    attr_accessor :content
    
    # Loads the file from Git, unless it's already been loaded.
    def load!
      @content ||= gash.send(:cat_file, @sha1)
    end
    
    def inspect #:nodoc:
      @content ? @content.inspect : (@sha1 ? "#<Blob:#{@sha1}>" : to_s.inspect) 
    end
    
    def <=>(other) #:nodoc:
      if other.is_a?(Blob) && sha1 && other.sha1
        sha1 <=> other.sha1
      else
        __getobj__ <=> other
      end
    end
    
    def __getobj__ #:nodoc:
      @content ||= @sha1 ? load! : ''
    end
    alias_method :to_s, :__getobj__
  end
  
  attr_accessor :branch, :repository
  
  # Opens the +repo+ with the specified +branch+.
  #
  # <strong>Please note:</strong> The +repo+ must link to the actual repo,
  # not the working directory!
  def initialize(branch = "master", repo = ".git")
    @branch = branch
    @repository = File.expand_path(repo)
    __setobj__(Tree.new(:parent => self))
    update!
  end
  
  def gash #:nodoc:
    self
  end
  
  def changed! #:nodoc:
    @sha1 = nil
  end
  
  # Fetch the latest data from Git; you can use this as a +clear+-method.
  def update!
    clear
    self.sha1 = git_tree_sha1
    git_tree do |line|
      line.strip!
      mode = line[0, 6]
      type = line[7]
      sha1 = line[12, 40]
      name = line[53..-1]
      if name[0] == ?" && name[-1] == ?"
        name = eval(name)
      end
      name = name[/[^\/]+$/]
      parent = if $`.empty?
        self
      else
        self[$`.chomp("/")]
      end
      parent[name, true] = case type
      when ?b
        Blob.new(:sha1 => sha1, :mode => mode)
      when ?t
        Tree.new(:sha1 => sha1, :mode => mode)
      end
    end
    self
  end
  
  # Commit the current changes and returns the commit-hash.
  #
  # Returns +nil+ if nothing has changed.
  def commit(msg)
    return unless changed?
    commit = commit_tree(to_tree!, msg)
    @sha1 = git_tree_sha1
    commit
  end
  
  # Checks if the current branch exists
  def branch_exists?
    git('rev-parse', @branch, '2>&1')
    true
  rescue Errors::Git
    false
  end
  
  def inspect #:nodoc:
    __getobj__.inspect
  end
  
  private
  
  def cat_file(blob)
    git('cat-file', 'blob', blob)
  end
  
  def to_tree!(from = self)
    input = []
    from.each do |key, value|
      key = key.inspect
      if value.tree?
        value.sha1 ||= to_tree!(value)
        value.mode ||= "040000"
        input << "#{value.mode} tree #{value.sha1}\t#{key}\n"
      else
        value.sha1 ||= git('hash-object', '-w', '--stdin', :input => value.to_s)
        value.mode ||= "100644" 
        input << "#{value.mode} blob #{value.sha1}\t#{key}\n"
      end
    end
    git('mktree', :input => input)
  end
  
  def update_head(new_head)
    git('update-ref', 'refs/heads/%s' % @branch, new_head)
  end  
  
  def commit_tree(tree, msg)
    if branch_exists?
      commit = git('commit-tree', tree, '-p', @branch, :input => msg)
      update_head(commit)
    else
      commit = git('commit-tree', tree, :input => msg)
      git('branch', @branch, commit)
    end
    commit
  end
  
  def git_tree(&blk)
    git('ls-tree', '-r', '-t', @branch, '2>&1') do |f|
      f.each_line(&blk)
    end
  rescue Errors::Git
    ""
  end
  
  def git_tree_sha1(from = @branch)
    git('rev-parse', @branch + '^{tree}', '2>&1')
  rescue Errors::Git
  end
  
  def method_missing(meth, *args, &blk)
    target = self.__getobj__
    unless target.respond_to?(meth)
      Object.instance_method(:method_missing).bind(self).call(meth, *args, &blk)
    end
    target.__send__(meth, *args, &blk)
  end
  
  # passes the command over to git
  #
  # ==== Parameters
  # cmd<String>:: the git command to execute
  # *rest:: any number of String arguments to the command, followed by an options hash
  # &block:: if you supply a block, you can communicate with git throught a pipe. NEVER even think about closing the stream!
  #
  # ==== Options
  # :strip<Boolean>:: true to strip the output String#strip, false not to to it
  #
  # ==== Raises
  # Errors::Git:: if git returns non-null, an Exception is raised
  #
  # ==== Returns
  # String:: if you didn't supply a block, the things git said on STDOUT, otherwise noting
  def git(cmd, *rest, &block)
    result, status = run_git(cmd, *rest, &block)

    if status != 0
      if result =~ /Not a git repository/
        raise Errors::NoGitRepo.new("No Git repository at: " + @repository)
      else
        raise Errors::Git.new("Error: #{cmd} returned #{status}. Result: #{result}")
      end
    end
    result
  end


  # passes the command over to git and returns its status ($?)
  #
  # ==== Parameters
  # cmd<String>:: the git command to execute
  # *rest:: any number of String arguments to the command, followed by an options hash
  # &block:: if you supply a block, you can communicate with git throught a pipe. NEVER even think about closing the stream!
  #
  # ==== Returns
  # Integer:: the return status of git
  def git_status(cmd, *rest, &block)
    run_git(cmd, *rest, &block)[1]
  end

  # passes the command over to git (you should not call this directly)
  #
  # ==== Parameters
  # cmd<String>:: the git command to execute
  # *rest:: any number of String arguments to the command, followed by an options hash
  # &block:: if you supply a block, you can communicate with git throught a pipe. NEVER even think about closing the stream!
  #
  # ==== Options
  # :strip<Boolean>:: true to strip the output String#strip, false not to to it
  #
  # ==== Raises
  # Errors::Git:: if git returns non-null, an Exception is raised
  #
  # ==== Returns
  # Array[String, Integer]:: the first item is the STDOUT of git, the second is the return-status
  def run_git(cmd, *args, &block)
    options = if args.last.kind_of?(Hash)
      args.pop
    else
      {}
    end

    options[:strip] = true unless options.key?(:strip)

    ENV["GIT_DIR"] = @repository
    cmd = "git #{cmd} #{args.join(' ')}"

    result = ""
    IO.popen(cmd, "w+") do |f|
      if input = options.delete(:input)
        f.write(input)
        f.close_write
      elsif block_given?
        yield f
        f.close_write
      end

      result = ""

      while !f.eof
        result << f.read
      end
    end
    status = $?

    result.strip! if options[:strip] == true

    [result, status]
  end
end