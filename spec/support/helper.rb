require "digest/sha1"
module Helper
  def path
    @@path ||= "/tmp/#{Digest::SHA1.hexdigest(Time.now.to_s)}"
  end

  def setup
    `mkdir #{path} && cd #{path} && git init`
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