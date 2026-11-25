# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::IdiomaticRails::ManualToSentence, :config do
  let(:config) { RuboCop::Config.new }

  it "registers an offense for joining with and" do
    expect_offense(<<~RUBY)
      names.join(" and ")
      ^^^^^^^^^^^^^^^^^^^ IdiomaticRails/ManualToSentence: Joining with " and " builds prose by hand — use `to_sentence`.
    RUBY
  end

  it "registers an offense for an Oxford separator" do
    expect_offense(<<~RUBY)
      parts.join(", and ")
      ^^^^^^^^^^^^^^^^^^^^ IdiomaticRails/ManualToSentence: Joining with ", and " builds prose by hand — use `to_sentence`.
    RUBY
  end

  it "accepts to_sentence" do
    expect_no_offenses("names.to_sentence")
  end

  # A delimiter is not prose.
  it "accepts an ordinary delimiter" do
    expect_no_offenses('names.join(", ")')
  end

  it "accepts a separator whose text merely contains the letters a-n-d" do
    expect_no_offenses('names.join(" standby ")')
  end

  it "accepts join with no argument" do
    expect_no_offenses("names.join")
  end
  # A string literal is bytes, not necessarily text. A regexp against one
  # that is not valid UTF-8 raises, and a cop that raises fails the run while
  # reporting nothing to fix.
  it "ignores a binary separator rather than dying on it" do
    expect_no_offenses(<<~'RUBY')
      parts.join("\xFF")
    RUBY
  end
end
