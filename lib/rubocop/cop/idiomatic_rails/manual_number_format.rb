# frozen_string_literal: true

module RuboCop
  module Cop
    module IdiomaticRails
      # A number rounded to a fixed number of decimal places with a format
      # string, where a Rails helper exists.
      #
      #   # bad
      #   "%.2f" % total
      #   format("%.2f", total)
      #   total.round(2).to_s
      #
      #   # good
      #   number_to_currency(total)
      #   number_to_percentage(rate, precision: 2)
      #   number_with_precision(total, precision: 2)
      #
      # The helpers carry the locale's delimiter, separator and currency unit.
      # `"%.2f"` carries none of them, so the first customer in a locale that
      # writes `1.234,56` sees `1234.56` — and the fix lands in one view while
      # the next still formats by hand.
      #
      # Only a *fixed-precision* float spec is reported. `"%d"` and `"%s"` are
      # not formatting a quantity for a reader, and `"%05.2f"` in a filename
      # or a protocol is a width contract rather than prose — the default
      # config excludes the places those live.
      class ManualNumberFormat < Base
        MSG = "Format the number with a Rails helper — number_to_currency, " \
              "number_to_percentage or number_with_precision — so it carries " \
              "the locale's separator and unit."

        FIXED_PRECISION = /%[-+ 0#]*\d*\.\d+f/

        def_node_matcher :percent_format, <<~PATTERN
          (send (str $_) :% _)
        PATTERN

        def_node_matcher :format_call, <<~PATTERN
          (send nil? {:format :sprintf} (str $_) _)
        PATTERN

        def_node_matcher :rounded_to_string?, <<~PATTERN
          (send (send _ :round (int _)) :to_s)
        PATTERN

        def on_send(node)
          if rounded_to_string?(node)
            add_offense(node)
            return
          end

          template = percent_format(node) || format_call(node)
          return unless template&.match?(FIXED_PRECISION)

          add_offense(node)
        end
      end
    end
  end
end
