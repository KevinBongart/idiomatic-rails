# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module IdiomaticRails
      # Flags `strftime` called with a literal format string.
      #
      # Rails has a place for these: `Date::DATE_FORMATS` and
      # `Time::DATE_FORMATS`, set once in an initializer and rendered with
      # `to_fs(:name)`. A format written inline is a format that will be
      # written again, slightly differently, in the next view — which is how
      # one screen comes to say "Aug 5" and the next "August 05".
      #
      # @example
      #   # bad
      #   date.strftime("%b %-d")
      #
      #   # good
      #   # config/initializers/time_formats.rb
      #   Date::DATE_FORMATS[:month_day_short] = "%b %-d"
      #   # anywhere
      #   date.to_fs(:month_day_short)
      #
      # Only a literal is reported. `date.strftime(format)` passes, because
      # the format is already a value somebody named.
      #
      # The default config excludes migrations, rake tasks, scripts and
      # specs, where a one-off format is usually the honest answer.
      class InlineStrftime < Base
        MSG = "Inline strftime format %<format>s — name it once in " \
              "`Date::DATE_FORMATS` (or `Time::DATE_FORMATS`) and use `to_fs(:name)`."
        RESTRICT_ON_SEND = %i[strftime].freeze

        def_node_matcher :literal_strftime, <<~PATTERN
          (send _ :strftime $str)
        PATTERN

        def on_send(node)
          literal_strftime(node) do |format|
            add_offense(node, message: format(MSG, format: format.source))
          end
        end
      end
    end
  end
end
