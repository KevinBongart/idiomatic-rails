# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module IdiomaticRails
      # Flags a list joined into prose with "and" by hand.
      #
      # `Array#to_sentence` is the Rails API for this. It handles the
      # two-item case ("a and b", no comma), the Oxford comma, the empty
      # list, and the locale — none of which a `join` does, and all of which
      # get discovered one bug at a time.
      #
      # @example
      #   # bad
      #   names.join(" and ")
      #   parts.join(", and ")
      #
      #   # good
      #   names.to_sentence
      #   names.to_sentence(last_word_connector: " and ")
      #
      # Only a separator containing the standalone word "and" is reported.
      # `join(", ")` is an ordinary delimiter and is left alone — a
      # delimiter is not prose.
      class ManualToSentence < Base
        MSG = "Joining with %<separator>s builds prose by hand — use `to_sentence`."
        RESTRICT_ON_SEND = %i[join].freeze

        def_node_matcher :join_with_separator, <<~PATTERN
          (send _ :join $str)
        PATTERN

        def on_send(node)
          join_with_separator(node) do |separator|
            next unless separator.value.match?(/\band\b/i)

            add_offense(node, message: format(MSG, separator: separator.source))
          end
        end
      end
    end
  end
end
