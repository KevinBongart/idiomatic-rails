# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::IdiomaticRails::HandRolledPluralization, :config do
  let(:config) { RuboCop::Config.new }

  describe "the shapes it exists for" do
    it "registers an offense for an if/else between singular and plural" do
      expect_offense(<<~RUBY)
        if count == 1
        ^^^^^^^^^^^^^ IdiomaticRails/HandRolledPluralization: Branching on a count to pick day/days — use `"day".pluralize(count)`.
          " (1 business day)"
        else
          " (\#{count} business days)"
        end
      RUBY
    end

    it "registers an offense for a ternary" do
      expect_offense(<<~RUBY)
        count == 1 ? "entry" : "entries"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdiomaticRails/HandRolledPluralization: Branching on a count to pick entry/entries — use `"entry".pluralize(count)`.
      RUBY
    end

    it "registers an offense when the plural comes first" do
      expect_offense(<<~RUBY)
        count != 1 ? "entries" : "entry"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdiomaticRails/HandRolledPluralization: Branching on a count to pick entry/entries — use `"entry".pluralize(count)`.
      RUBY
    end

    it "registers an offense for a suffix appended inside an interpolation" do
      expect_offense(<<~'RUBY')
        "#{count} day#{'s' unless count == 1}"
                       ^^^^^^^^^^^^^^^^^^^^^ IdiomaticRails/HandRolledPluralization: Appending a plural suffix conditionally — use `String#pluralize(count)` on the whole word.
      RUBY
    end

    # The reason to prefer the inflector over a branch, in one example.
    it "registers an offense for an irregular plural" do
      expect_offense(<<~RUBY)
        count == 1 ? "person" : "people"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdiomaticRails/HandRolledPluralization: Branching on a count to pick person/people — use `"person".pluralize(count)`.
      RUBY
    end
  end

  describe "what it must leave alone" do
    it "accepts String#pluralize" do
      expect_no_offenses('"entry".pluralize(count)')
    end

    # Comparing against 1 is what makes a conditional a count branch.
    it "accepts a conditional that is not comparing a count" do
      expect_no_offenses('status == :draft ? "draft" : "published"')
    end

    it "accepts two strings that are not a singular/plural pair" do
      expect_no_offenses('count > 1 ? "many" : "few"')
    end

    it "accepts a word the inflector does not pluralise" do
      expect_no_offenses('count == 1 ? "sheep" : "sheep"')
    end

    it "accepts an interpolation that is not a plural suffix" do
      expect_no_offenses(<<~'RUBY')
        "#{count} day#{' ago' if count == 1}"
      RUBY
    end
  end
end
