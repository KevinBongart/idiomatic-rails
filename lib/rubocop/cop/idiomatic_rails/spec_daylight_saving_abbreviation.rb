# frozen_string_literal: true

module RuboCop
  module Cop
    module IdiomaticRails
      # A time-zone abbreviation that changes with daylight saving, written
      # into a spec as a literal.
      #
      #   # bad
      #   expect(page).to have_content("7:00 PM–10:00 PM (CEST)")
      #
      #   # good — pin the date the abbreviation belongs to
      #   event = create(:event, date: Date.new(2026, 10, 10))
      #   expect(page).to have_content("6:00 PM–9:00 PM (CEST)")
      #
      # Europe moved from CEST to CET at 03:00 on the last Sunday of October.
      # Three spec files in the application this came from asserted `(CEST)`
      # against an event the factory dated at `Date.current + 7.days`; two of
      # them went red that morning and would have stayed red until late March.
      #
      # Only abbreviations that *flip* are reported. `UTC` and `GMT` do not
      # observe daylight saving, so a literal one is stable and says what it
      # means.
      class SpecDaylightSavingAbbreviation < Base
        MSG = "`%<abbreviation>s` flips with daylight saving. Pin the date this " \
              "belongs to, or assert something the clock does not change."

        # Paired summer/winter abbreviations. A literal one is only correct
        # for part of the year unless the date is pinned.
        FLIPPING = %w[
          CET CEST
          EET EEST
          WET WEST
          EST EDT CST CDT MST MDT PST PDT
          AEST AEDT ACST ACDT AWST
          NZST NZDT
          BST IST
        ].freeze

        PATTERN = /\(?\b(#{FLIPPING.join('|')})\b\)?/

        def on_str(node)
          return unless node.loc.respond_to?(:begin)

          match = node.value.match(PATTERN)
          return unless match

          add_offense(node, message: format(MSG, abbreviation: match[1]))
        end
      end
    end
  end
end
