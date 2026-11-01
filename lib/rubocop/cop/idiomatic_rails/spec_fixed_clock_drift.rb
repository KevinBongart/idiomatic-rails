# frozen_string_literal: true

module RuboCop
  module Cop
    module IdiomaticRails
      # An example that pins a time, and then builds data with a helper that
      # reads the real clock.
      #
      #   # bad
      #   let(:now) { Time.zone.local(2026, 9, 1, 18) }
      #   create_events(1, created_at: 1.month.ago)
      #
      #   # good
      #   let(:now) { Time.zone.local(2026, 9, 1, 18) }
      #   create_events(1, created_at: now - 1.month)
      #
      # The two clocks agree for most of the year and then stop. The example
      # this was extracted from pinned `now` to 1 September and dated its
      # "previous month" fixture with `1.month.ago`. From 1 October the real
      # clock's answer landed *inside* the pinned month, both fixtures counted,
      # and it failed every run until November — with nobody having touched
      # the code. A second example in the same file carried the same bug with
      # `1.year.ago`, which would have waited until 2027 to go off.
      #
      # The fix is not to freeze harder. It is to offset from the clock the
      # example already declares, so it depends on one clock rather than two.
      #
      # `travel_to` is deliberately not treated as a pin: it moves the real
      # clock, so `1.month.ago` underneath it is consistent.
      class SpecFixedClockDrift < Base
        MSG = "This file pins a clock (`%<pin>s`), so offset from it — " \
              "`%<pin>s - %<duration>s` — rather than from the real one."

        RELATIVE = %i[ago from_now until since].freeze

        # A literal time bound to a name is what fixes an example's clock.
        # A literal time bound to a name is what fixes an example's clock.
        # `Time.zone.local(...)` is the common spelling, and its receiver is
        # `Time.zone` rather than `Time`, so both shapes are matched.
        def_node_matcher :clock_constructor?, <<~PATTERN
          (send
            {(const {nil? cbase} {:Time :Date :DateTime})
             (send (const {nil? cbase} {:Time :Date :DateTime}) :zone)}
            {:local :new :parse :at :utc}
            ...)
        PATTERN

        def_node_matcher :named_binding, <<~PATTERN
          (block (send nil? {:let :let!} (sym $_)) ...)
        PATTERN

        def on_new_investigation
          super
          @pins = []
          ast = processed_source.ast
          return unless ast

          ast.each_node(:block) do |block|
            name = named_binding(block)
            next unless name
            next unless block.body && pins_a_clock?(block.body)

            @pins << name
          end
        end

        def pins_a_clock?(node)
          return true if clock_constructor?(node)

          node.each_descendant(:send).any? { |child| clock_constructor?(child) }
        end

        def on_send(node)
          return if @pins.nil? || @pins.empty?
          return unless RELATIVE.include?(node.method_name)
          return unless bare_duration?(node.receiver)

          add_offense(
            node,
            message: format(MSG, pin: @pins.first, duration: node.receiver.source)
          )
        end

        private

        # `1.month.ago` drifts; `now - 1.month` and `event.created_at.ago` do
        # not, because they already name what they are relative to.
        def bare_duration?(receiver)
          receiver&.send_type? && receiver.receiver&.numeric_type?
        end
      end
    end
  end
end
