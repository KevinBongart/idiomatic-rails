# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::IdiomaticRails::SpecDaylightSavingAbbreviation, :config do
  it "flags a summer abbreviation" do
    expect_offense(<<~RUBY, "spec/requests/events_spec.rb")
      expect(page).to have_content("7:00 PM-10:00 PM (CEST)")
                                   ^^^^^^^^^^^^^^^^^^^^^^^^^ `CEST` flips with daylight saving. Pin the date this belongs to, or assert something the clock does not change.
    RUBY
  end

  it "flags the winter half of the same pair" do
    expect_offense(<<~RUBY, "spec/requests/events_spec.rb")
      expect(body).to include("6:00 PM-9:00 PM (CET)")
                              ^^^^^^^^^^^^^^^^^^^^^^^ `CET` flips with daylight saving. Pin the date this belongs to, or assert something the clock does not change.
    RUBY
  end

  # UTC and GMT do not observe daylight saving, so a literal one is stable.
  it "accepts an abbreviation that does not flip" do
    expect_no_offenses(<<~RUBY, "spec/requests/events_spec.rb")
      expect(body).to include("6:00 PM-9:00 PM (UTC)")
      expect(body).to include("6:00 PM-9:00 PM (GMT)")
    RUBY
  end

  it "does not fire on an unrelated word" do
    expect_no_offenses(<<~RUBY, "spec/requests/events_spec.rb")
      expect(body).to include("The best time to visit")
    RUBY
  end
  # A string literal does not have to be valid UTF-8. Matching a regexp
  # against one that is not raises ArgumentError, and a cop that *errors*
  # fails the whole run while reporting no offenses — rubocop exits 1 with
  # nothing to fix, which is worse than a false positive because there is
  # nothing to correct.
  it "ignores a binary literal rather than dying on it" do
    expect_no_offenses(<<~'RUBY', "spec/bin/upload_spec.rb")
      File.binwrite(path, "\x00\xFF".b)
    RUBY
  end

  it "ignores a binary literal that happens to hold flipping letters" do
    expect_no_offenses(<<~'RUBY', "spec/bin/upload_spec.rb")
      stub_request(:put, url).with(body: "EST\xFF".b)
    RUBY
  end
end
