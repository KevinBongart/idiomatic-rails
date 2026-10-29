# frozen_string_literal: true

require "rubocop"
require "active_support/core_ext/string/inflections"

module RuboCop
  module Cop
    module IdiomaticRails
      # Flags a singular/plural word picked by branching on a count, which
      # `String#pluralize` already does — and does for the irregular words a
      # hand-written branch gets wrong the first time someone counts
      # "person" or "analysis".
      #
      # @example
      #   # bad
      #   count == 1 ? "entry" : "entries"
      #
      #   # bad
      #   if count == 1
      #     " (1 business day)"
      #   else
      #     " (#{count} business days)"
      #   end
      #
      #   # bad
      #   "#{count} day#{'s' unless count == 1}"
      #
      #   # good
      #   "entry".pluralize(count)
      #   " (#{count} #{'business day'.pluralize(count)})"
      #
      # The test for "these two words are a singular/plural pair" is
      # ActiveSupport's inflector — the same one the correction would use,
      # and the same one an application's `inflections.rb` configures. So the
      # cop cannot disagree with the fix it asks for, and a word the
      # inflector would not change (`"sheep"`, `"is"`/`"are"`) is not
      # reported, because `.pluralize` would not fix it either.
      #
      # Comparing against `1` is what makes a conditional a *count* branch.
      # Without that test, every two-string conditional in an application
      # would be an offense.
      class HandRolledPluralization < Base
        MSG = "Branching on a count to pick %<singular>s/%<plural>s — " \
              "use `\"%<singular>s\".pluralize(count)`."
        SUFFIX_MSG = "Appending a plural suffix conditionally — " \
                     "use `String#pluralize(count)` on the whole word."
        CONDITIONAL_SUFFIX = %w[s es].freeze

        def_node_matcher :count_comparison?, <<~PATTERN
          (send _ {:== :!= :> :< :>= :<=} (int 1))
        PATTERN

        def on_if(node)
          return add_offense(node, message: SUFFIX_MSG) if conditional_suffix?(node)
          return unless count_comparison?(node.condition)

          singular, plural = inflection_pair(node.if_branch, node.else_branch)
          return unless singular

          add_offense(node, message: format(MSG, singular: singular, plural: plural))
        end

        private

        # `"day#{'s' unless count == 1}"` — the branch sits inside a string
        # and yields the suffix rather than the whole word.
        def conditional_suffix?(node)
          return false unless node.parent&.begin_type? && node.parent.parent&.dstr_type?
          return false unless count_comparison?(node.condition)

          [ node.if_branch, node.else_branch ].compact.all? do |branch|
            branch.str_type? && CONDITIONAL_SUFFIX.include?(branch.value)
          end
        end

        # Checked both ways round, since either branch may hold the singular.
        def inflection_pair(left, right)
          one = last_word(left)
          other = last_word(right)
          return if one.nil? || other.nil? || one.casecmp?(other)

          return [ one, other ] if one.pluralize == other
          return [ other, one ] if other.pluralize == one

          nil
        end

        # The literal text of a string with interpolation dropped: the words
        # on either side of `#{count}` are what is being pluralised.
        def last_word(node)
          return unless node

          text =
            case node.type
            when :str then node.value
            when :dstr then node.children.select(&:str_type?).map(&:value).join
            end

          text&.scan(/[A-Za-z]+/)&.last
        end
      end
    end
  end
end
