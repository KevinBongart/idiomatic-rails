# frozen_string_literal: true

module RuboCop
  module Cop
    module IdiomaticRails
      # A fixed sleep standing in for a synchronisation point.
      #
      #   # bad
      #   click_button "Save"
      #   sleep 0.5
      #   expect(page).to have_content("Saved")
      #
      #   # good — wait for the state that makes the next step possible
      #   click_button "Save"
      #   expect(page).to have_content("Saved")
      #
      # Capybara's matchers already wait. A `sleep` is slower than the wait
      # it replaces on a fast machine and shorter than it on a slow one, so it
      # buys flakiness and spends time to do it.
      #
      # The rule it enforces is the playbook's: after browser navigation or
      # history restoration, synchronise on the observable state that makes
      # the next interaction possible — rendered frame content, an enabled
      # control, a focusable element — and do not replace that boundary with
      # a fixed sleep or an automatic retry.
      class SpecSleep < Base
        MSG = "Wait for the state that makes the next step possible, not for " \
              "a fixed duration — Capybara's matchers already block."

        def_node_matcher :bare_sleep?, "(send nil? :sleep ...)"

        def on_send(node)
          return unless bare_sleep?(node)

          add_offense(node)
        end
      end
    end
  end
end
