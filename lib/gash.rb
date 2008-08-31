require 'delegate'

class Gash < SimpleDelegator
  module Helpers
    attr_accessor :sha1, :mode
    def blob?;    self.class == Gash::Blob; end
    def tree?;    self.class == Gash::Tree; end
    def changed?; !@sha1 end
  end
  
  class Tree < Hash
    include Helpers
    
    def initialize(opts = {})
      @sha1 = opts[:sha1]
      @mode = opts[:mode]
    end
    
    def [](key, lazy = nil)
      ret = if key.include?("/")
        key, rest = key.split("/", 2)
        value = super(key)
        return if value.nil?
        value[rest]
      else
        super(key)
      end
      ret.load! if ret.is_a?(Gash::Blob) && !lazy
      ret
    end
    alias / []
    
    def []=(*a)
      case a.length
      when 3
        key, keep_sha1, value = [*a]
      when 2
        key, value = [*a]
      end
      
      if key.include?("/")
        keys = key.split("/")
        name = keys.pop
        keys.inject(self) do |memo, i|
          memo[i] = Tree.new unless memo.include?(i)
          memo[i, true]
        end[name, keep_sha1] = value
      else
        value = case value
        when Tree, Blob
          value
        else
          Blob.new(:content => value.to_s)
        end
        super(key, value)
      end
    ensure
      @sha1 = nil unless keep_sha1
    end
  end
  
  class Blob < Delegator
    include Helpers
    attr_accessor :mode, :sha1
    
    def initialize(opts = {})
      @gash = opts[:gash]
      @mode = opts[:mode]
      @sha1 = opts[:sha1]
      @content = opts[:content]
    end
    
    def inspect
      @content ? @content.inspect : (@sha1 ? "#<Blob:#{@sha1}>" : to_s.inspect) 
    end
    
    def load!
      @content ||= @gash.send(:cat_file, @sha1)
    end
    
    def __getobj__
      @content ||= @sha1 ? load! : ''
    end
    alias to_s __getobj__
  end
  
  attr_accessor :branch, :repository
  
  def initialize(branch, repo = ".")
    @branch = branch
    @repository = File.expand_path(repo)
    __setobj__(Tree.new)
    update!
  end
  
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
      self[name, true] = case type
      when ?b
        Blob.new(:gash => self, :sha1 => sha1, :mode => mode)
      when ?t
        Tree.new(:sha1 => sha1, :mode => mode)
      end
    end
    self
  end
  
  def changed(file)
    self[file] = self[file]
  end 
  
  def commit(msg)
    return unless changed?
    commit = commit_tree(to_tree!, msg)
    @sha1 = git_tree_sha1
    commit
  end
  
  def branch_exists?
    git('rev-parse', @branch, '2>&1')
    true
  rescue GitError
    false
  end
  
  def inspect
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
  rescue GitError
    ""
  end
  
  def git_tree_sha1(from = @branch)
    git('rev-parse', @branch + '^{tree}', '2>&1')
  rescue GitError
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
  # GitError:: if git returns non-null, an Exception is raised
  #
  # ==== Returns
  # String:: if you didn't supply a block, the things git said on STDOUT, otherwise noting
  def git(cmd, *rest, &block)
    result, status = run_git(cmd, *rest, &block)

    if status != 0
      raise GitError.new("Error: #{cmd} returned #{status}. Result: #{result}")
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
  # GitError:: if git returns non-null, an Exception is raised
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
    cmd = "git-#{cmd} #{args.join(' ')}"

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
  
  class GitError < StandardError
  end
end