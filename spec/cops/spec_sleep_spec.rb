# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::IdiomaticRails::SpecSleep, :config do
  it "flags a fixed sleep" do
    expect_offense(<<~RUBY, "spec/system/event_spec.rb")
      click_button "Save"
      sleep 0.5
      ^^^^^^^^^ Wait for the state that makes the next step possible, not for a fixed duration — Capybara's matchers already block.
    RUBY
  end

  it "accepts waiting on observable state" do
    expect_no_offenses(<<~RUBY, "spec/system/event_spec.rb")
      click_button "Save"
      expect(page).to have_content("Saved")
    RUBY
  end

  # A `sleep` on an object is somebody's own method, not Kernel#sleep.
  it "does not fire on a receiver's own sleep" do
    expect_no_offenses(<<~RUBY, "spec/system/event_spec.rb")
      scheduler.sleep(1)
    RUBY
  end
end
