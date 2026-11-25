# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::IdiomaticRails::DateFormatWithoutExample, :config do
  it "flags a format defined with no example" do
    expect_offense(<<~RUBY)
      Time::DATE_FORMATS[:month_and_day] = "%B %-d"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Name the format and show it: add an example of what "%B %-d" renders.
    RUBY

    expect_correction(<<~RUBY)
      # "November 5"
      Time::DATE_FORMATS[:month_and_day] = "%B %-d"
    RUBY
  end

  it "flags a Date format too" do
    expect_offense(<<~RUBY)
      Date::DATE_FORMATS[:week_day_and_date] = "%A, %b %d %Y"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Name the format and show it: add an example of what "%A, %b %d %Y" renders.
    RUBY

    expect_correction(<<~RUBY)
      # "Saturday, Nov 05 1955"
      Date::DATE_FORMATS[:week_day_and_date] = "%A, %b %d %Y"
    RUBY
  end

  it "accepts a format with an example on the line above" do
    expect_no_offenses(<<~RUBY)
      # "November 5"
      Time::DATE_FORMATS[:month_and_day] = "%B %-d"
    RUBY
  end

  it "accepts a format with a trailing example" do
    expect_no_offenses(<<~RUBY)
      Time::DATE_FORMATS[:month_and_day] = "%B %-d" # "November 5"
    RUBY
  end

  # The moment is chosen so that the pairs a reader cannot tell apart render
  # differently: a single-digit day for %-d against %d, an evening hour for
  # %H against %I.
  it "renders an example that distinguishes the ambiguous directives" do
    expect_offense(<<~RUBY)
      Time::DATE_FORMATS[:spelled_out] = "%d/%-d %H/%-I %p"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Name the format and show it: add an example of what "%d/%-d %H/%-I %p" renders.
    RUBY

    expect_correction(<<~RUBY)
      # "05/5 22/10 PM"
      Time::DATE_FORMATS[:spelled_out] = "%d/%-d %H/%-I %p"
    RUBY
  end

  it "keeps the indentation of what it documents" do
    expect_offense(<<~RUBY)
      if Rails.env.development?
        Time::DATE_FORMATS[:month_and_day] = "%B %-d"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Name the format and show it: add an example of what "%B %-d" renders.
      end
    RUBY

    expect_correction(<<~RUBY)
      if Rails.env.development?
        # "November 5"
        Time::DATE_FORMATS[:month_and_day] = "%B %-d"
      end
    RUBY
  end

  it "ignores an unrelated hash assignment" do
    expect_no_offenses(<<~RUBY)
      SETTINGS[:month_and_day] = "%B %-d"
    RUBY
  end

  # A computed format cannot be rendered at inspection time, so there is no
  # single obvious correction to offer.
  it "ignores a format that is not a literal" do
    expect_no_offenses(<<~RUBY)
      Time::DATE_FORMATS[:computed] = build_format
    RUBY
  end

  # The first version accepted any comment, which meant a group heading
  # exempted the format under it — silently, in the very initializer this
  # was written for.
  it "does not accept a group heading as an example" do
    expect_offense(<<~RUBY)
      # Admin dashboard
      Time::DATE_FORMATS[:month_and_day] = "%B %-d"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Name the format and show it: add an example of what "%B %-d" renders.
    RUBY

    expect_correction(<<~RUBY)
      # Admin dashboard
      # "November 5"
      Time::DATE_FORMATS[:month_and_day] = "%B %-d"
    RUBY
  end

  it "accepts a single-quoted example" do
    expect_no_offenses(<<~RUBY)
      # 'November 5'
      Time::DATE_FORMATS[:month_and_day] = "%B %-d"
    RUBY
  end

  # The example is not always the last thing said about a format. Reading
  # only the line above calls this undocumented, which is both wrong and an
  # argument for writing less.
  it "accepts an example anywhere in the comment block above" do
    expect_no_offenses(<<~RUBY)
      # "November 25, 2026 at 9:30:15 AM EST"
      # Seconds and the zone are both load-bearing: this is the admin
      # table's title text, where two rows can share a minute.
      Time::DATE_FORMATS[:admin_timestamp] = "%B %-d, %Y at %-I:%M:%S %p %Z"
    RUBY
  end

  # Stopping at the first non-comment line is what keeps one format from
  # borrowing the example belonging to the one above it.
  it "does not let a format borrow the example above a blank line" do
    expect_offense(<<~RUBY)
      # "November 5"
      Time::DATE_FORMATS[:documented] = "%B %-d"

      Time::DATE_FORMATS[:undocumented] = "%B %Y"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Name the format and show it: add an example of what "%B %Y" renders.
    RUBY
  end
end
