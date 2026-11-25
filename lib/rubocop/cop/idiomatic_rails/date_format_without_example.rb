# frozen_string_literal: true

module RuboCop
  module Cop
    module IdiomaticRails
      # A named date format defined without an example of what it renders.
      #
      #   # bad
      #   Time::DATE_FORMATS[:month_and_day] = "%B %-d"
      #
      #   # good
      #   # "November 5"
      #   Time::DATE_FORMATS[:month_and_day] = "%B %-d"
      #
      # Naming a format is the correction `InlineStrftime` asks for, and it
      # trades one problem for another: `to_fs(:month_and_day)` at the call
      # site says what the format is *for*, and no longer says what it looks
      # like. The initializer becomes the only place that answer exists, and
      # there it is written in strftime — which almost nobody reads fluently.
      # `%-d` against `%d`, `%-I` against `%I`, `%e` against `%d`: each pair
      # differs by a space or a zero, and telling them apart means running
      # the thing.
      #
      # So the example is not decoration. It is the only form of the answer a
      # reader can check at a glance, and it belongs next to the definition
      # because that is where someone adding the next format will look.
      #
      # The cop requires a quoted example, not a particular one. Which
      # moment makes a format legible is a judgement, so the autocorrection
      # offers one rather than insisting on it.
      class DateFormatWithoutExample < Base
        extend AutoCorrector

        MSG = "Name the format and show it: add an example of what " \
              "%<format>s renders."

        # November 5th, 1955: Doc Brown slips, hits his head, and comes to
        # with the flux capacitor. The time is the other famous minute of
        # that month — 10:04 PM, when the lightning hits the clock tower.
        #
        # A fixed moment rather than `Time.now`, because an example that
        # changes under you is not an example, and because the cop has to
        # reach the same verdict on every run. This one also happens to
        # exercise the pairs that are hard to read: the day is a single
        # digit, so `%-d` and `%d` differ; the hour is past noon, so `%H`
        # and `%I` differ.
        EXAMPLE_MOMENT = Time.utc(1955, 11, 5, 22, 4, 0)

        RESTRICT_ON_SEND = %i[[]=].freeze

        # `DATE_FORMATS[:name] = "..."` parses as a `[]=` send rather than an
        # index assignment, so the cop hooks `on_send`.
        # @!method date_format_assignment(node)
        def_node_matcher :date_format_assignment, <<~PATTERN
          (send (const (const nil? {:Date :Time}) :DATE_FORMATS) :[]= _ $str)
        PATTERN

        def on_send(node)
          date_format_assignment(node) do |format|
            next if documented?(node)

            add_offense(node, message: format(MSG, format: format.source)) do |corrector|
              corrector.insert_before(node, "#{example_comment(format)}\n#{indentation(node)}")
            end
          end
        end

        private

        # The example is a *quoted* rendering, on the line above or trailing
        # on the same line.
        #
        # Requiring the quotes rather than accepting any comment is what the
        # first version of this got wrong. A group heading is a comment:
        #
        #   # Admin dashboard
        #   Time::DATE_FORMATS[:month_and_day] = "%B %-d"
        #
        # and accepting it exempted the first format under every heading —
        # silently, and in the one initializer this cop was written for. A
        # heading says what a group is; it never says what a format renders.
        EXAMPLE = /["'][^"']*["']/

        def documented?(node)
          line = node.loc.line

          processed_source.comments.any? do |comment|
            (comment.loc.line == line || comment.loc.line == line - 1) &&
              comment.text.match?(EXAMPLE)
          end
        end

        def example_comment(format)
          %(# "#{rendered(format.value)}")
        end

        # Rendering can fail on a format this cop has no business judging —
        # an encoding the moment cannot express, a directive strftime
        # rejects. The format's own text is then the honest fallback.
        def rendered(format)
          EXAMPLE_MOMENT.strftime(format)
        rescue StandardError
          format
        end

        def indentation(node)
          " " * node.loc.column
        end
      end
    end
  end
end
