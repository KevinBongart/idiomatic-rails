# frozen_string_literal: true

require_relative "lib/idiomatic_rails/version"

Gem::Specification.new do |spec|
  spec.name = "idiomatic-rails"
  spec.version = IdiomaticRails::VERSION
  spec.authors = [ "Kevin Bongart" ]

  spec.summary = "Deterministic checks that a Rails app uses Rails, instead of reimplementing it"
  spec.description = <<~TEXT
    RuboCop cops and a reachability check for the things Rails already does and
    an application keeps rewriting: pluralising by branching on a count,
    formatting a date with an inline strftime, joining a list with "and" by
    hand. Plus a cross-file check for methods and constants nothing but their
    own spec reaches.

    Every rule is deterministic — it fires on a shape, not on a smell — and
    each is argued for in the README with the case it was extracted from.
  TEXT
  spec.homepage = "https://github.com/KevinBongart/idiomatic-rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["default_lint_roller_plugin"] = "IdiomaticRails::Plugin"

  spec.files = Dir["lib/**/*.rb", "exe/*", "config/*.yml", "*.md", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = [ "idiomatic-rails-dead-code", "idiomatic-rails-unenforced-validations" ]
  spec.require_paths = [ "lib" ]

  # actionview compiles ERB templates for the reachability check, so a helper
  # called only from a view is not reported as dead. activesupport's inflector
  # is the oracle the pluralisation cop checks word pairs against — the same
  # one the fix it asks for would use.
  spec.add_dependency "actionview", ">= 7.1"
  spec.add_dependency "activesupport", ">= 7.1"
  spec.add_dependency "prism", ">= 1.0"
  spec.add_dependency "rubocop", ">= 1.72"
end
