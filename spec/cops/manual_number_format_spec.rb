# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::IdiomaticRails::ManualNumberFormat, :config do
  it "flags a percent-formatted fixed precision" do
    expect_offense(<<~RUBY)
      "%.2f" % total
      ^^^^^^^^^^^^^^ Format the number with a Rails helper — number_to_currency, number_to_percentage or number_with_precision — so it carries the locale's separator and unit.
    RUBY
  end

  it "flags format and sprintf" do
    expect_offense(<<~RUBY)
      format("%.2f", total)
      ^^^^^^^^^^^^^^^^^^^^^ Format the number with a Rails helper — number_to_currency, number_to_percentage or number_with_precision — so it carries the locale's separator and unit.
    RUBY
  end

  it "flags rounding to a string" do
    expect_offense(<<~RUBY)
      total.round(2).to_s
      ^^^^^^^^^^^^^^^^^^^ Format the number with a Rails helper — number_to_currency, number_to_percentage or number_with_precision — so it carries the locale's separator and unit.
    RUBY
  end

  # Not formatting a quantity for a reader.
  it "accepts an integer or string spec" do
    expect_no_offenses(<<~RUBY)
      "%d items" % count
      format("%s", name)
    RUBY
  end

  it "accepts the Rails helpers" do
    expect_no_offenses(<<~RUBY)
      number_to_currency(total)
      number_with_precision(total, precision: 2)
    RUBY
  end

  it "accepts rounding that is not turned into a string" do
    expect_no_offenses(<<~RUBY)
      total.round(2)
    RUBY
  end
end
