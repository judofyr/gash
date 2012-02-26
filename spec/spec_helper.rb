require "rspec"
require "gash"
require "./spec/support/helper"

RSpec.configure do |config|
  config.mock_with :rspec
  config.include Helper
  config.before(:each) { setup }
  config.after(:each) { teardown }
end