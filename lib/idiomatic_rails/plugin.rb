# frozen_string_literal: true

require "lint_roller"

module IdiomaticRails
  # Registers the cops with RuboCop, so a host application writes
  #
  #   plugins:
  #     - idiomatic-rails
  #
  # in .rubocop.yml rather than requiring a path. The plugin API is how
  # RuboCop has wanted extensions loaded since 1.72; `require:` still works
  # and prints a deprecation.
  class Plugin < LintRoller::Plugin
    def about
      LintRoller::About.new(
        name: "idiomatic-rails",
        version: VERSION,
        homepage: "https://github.com/KevinBongart/idiomatic-rails",
        description: "Deterministic checks that a Rails app uses Rails, instead of reimplementing it."
      )
    end

    def supported?(context)
      context.engine == :rubocop
    end

    def rules(_context)
      LintRoller::Rules.new(
        type: :path,
        config_format: :rubocop,
        value: Pathname.new(__dir__).join("../../config/default.yml")
      )
    end
  end
end

require_relative "../rubocop/cop/idiomatic_rails/hand_rolled_pluralization"
require_relative "../rubocop/cop/idiomatic_rails/inline_strftime"
require_relative "../rubocop/cop/idiomatic_rails/manual_to_sentence"
