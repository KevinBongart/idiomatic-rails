# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::IdiomaticRails::InlineStrftime, :config do
  let(:config) { RuboCop::Config.new }

  it "registers an offense for a literal format" do
    expect_offense(<<~RUBY)
      date.strftime("%b %-d")
      ^^^^^^^^^^^^^^^^^^^^^^^ IdiomaticRails/InlineStrftime: Inline strftime format "%b %-d" — name it once in `Date::DATE_FORMATS` (or `Time::DATE_FORMATS`) and use `to_fs(:name)`.
    RUBY
  end

  it "registers an offense on a Time as well as a Date" do
    expect_offense(<<~RUBY)
      Time.current.strftime("%H:%M")
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdiomaticRails/InlineStrftime: Inline strftime format "%H:%M" — name it once in `Date::DATE_FORMATS` (or `Time::DATE_FORMATS`) and use `to_fs(:name)`.
    RUBY
  end

  it "accepts to_fs with a named format" do
    expect_no_offenses("date.to_fs(:month_day_short)")
  end

  # The format is already a value somebody named, which is the whole ask.
  it "accepts strftime with a non-literal format" do
    expect_no_offenses("date.strftime(format)")
  end

  it "accepts the initializer line that defines a named format" do
    expect_no_offenses('Date::DATE_FORMATS[:month_day_short] = "%b %-d"')
  end
end
