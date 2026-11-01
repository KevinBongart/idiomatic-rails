# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::IdiomaticRails::SpecFixedClockDrift, :config do
  it "flags a bare duration in a file that pins a clock" do
    expect_offense(<<~RUBY, "spec/models/thing_spec.rb")
      RSpec.describe AiTaggingUsage do
        let(:now) { Time.zone.local(2026, 9, 1, 18) }

        it "excludes prior-month events" do
          create_event(created_at: 1.month.ago)
                                   ^^^^^^^^^^^ This file pins a clock (`now`), so offset from it — `now - 1.month` — rather than from the real one.
        end
      end
    RUBY
  end

  it "accepts an offset from the pinned clock" do
    expect_no_offenses(<<~RUBY, "spec/models/thing_spec.rb")
      RSpec.describe AiTaggingUsage do
        let(:now) { Time.zone.local(2026, 9, 1, 18) }

        it "excludes prior-month events" do
          create_event(created_at: now - 1.month)
        end
      end
    RUBY
  end

  # travel_to moves the real clock, so a relative helper under it agrees
  # with everything else.
  it "accepts a relative helper when nothing pins a literal time" do
    expect_no_offenses(<<~RUBY, "spec/models/thing_spec.rb")
      RSpec.describe Thing do
        it "looks back" do
          travel_to Time.zone.local(2026, 9, 1)
          create_event(created_at: 1.month.ago)
        end
      end
    RUBY
  end

  it "accepts a duration anchored to a value" do
    expect_no_offenses(<<~RUBY, "spec/models/thing_spec.rb")
      RSpec.describe Thing do
        let(:now) { Time.zone.local(2026, 9, 1, 18) }

        it "looks back" do
          create_event(created_at: event.created_at.ago)
        end
      end
    RUBY
  end
end
