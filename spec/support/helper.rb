require "tmpdir"
module Helper
  def path
    @path ||= Dir.mktmpdir
  end

  def setup
    `cd #{path} && git init`
  end

  def teardown
    `rm -rf #{path}`
  end

  #
  # @hash String A commit hash
  # @return Array<String> A list of files
  #
  def list_files(hash)
    `cd #{path} && git show --pretty='format:' --name-only #{hash}`.strip.split("\n")
  end

  #
  # @return String Diff content for last commit
  #
  def content
    `cd #{path} && git show HEAD`
  end

  #
  # @dir String Folder to retrive
  # @return String 
  #   Example: 040000 tree d91d06157bdc633d25f970b9cc54d0eb74fb850f my-folder
  #
  def folder(dir)
    tree = `cd #{path} && git cat-file -p HEAD`.split(" ")[1]
    `cd #{path} && git cat-file -p #{tree}`.split("\n").select do |row| 
      row.match(/#{dir}/) and row.match(/tree/)
    end.first
  end

  #
  # @return String The last commit message
  #
  def last_commit_message
    `cd #{path} && git log --pretty='format:%s' -n 1`
  end

  #
  # @return String
  # @example
  #   commit 5b580afc95c32721d35a7d659abce1e3845635a9
  #   Author:     Linus Oleander <linus@oleander.nu>
  #   AuthorDate: Mon Feb 27 23:16:59 2012 +0100
  #   Commit:     Linus Oleander <linus@oleander.nu>
  #   CommitDate: Mon Feb 27 23:16:59 2012 +0100
  #
  #       Add last_commit_message helper
  #
  #   M       spec/support/helper.rb
  #
  def raw_commit
    `cd #{path} && git show --name-status --format=fuller`
  end
end