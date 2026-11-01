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
end
