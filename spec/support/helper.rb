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
end