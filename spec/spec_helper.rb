# frozen_string_literal: true

require "rubocop"
# rubocop before rubocop/rspec/support: support loads only the RSpec helpers
# and leaves RuboCop::Cop half-defined, so requiring the real thing after it
# dies with `superclass mismatch for class Cop`.
require "rubocop/rspec/support"
require "idiomatic-rails"
require "idiomatic_rails/dead_code"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)
end
