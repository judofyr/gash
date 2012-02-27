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
end