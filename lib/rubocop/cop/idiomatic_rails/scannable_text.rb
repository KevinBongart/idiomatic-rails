# frozen_string_literal: true

module RuboCop
  module Cop
    module IdiomaticRails
      # Guards the cops that read what a string literal *says*.
      #
      # A Ruby string literal is a sequence of bytes, not necessarily text.
      # `"\x00\xFF"` is a perfectly ordinary literal — specs that exercise
      # binary payloads are full of them — and it carries the source file's
      # encoding, so it arrives here tagged UTF-8 while holding bytes that are
      # not valid UTF-8. Every regexp operation on such a string raises
      # `ArgumentError: invalid byte sequence in UTF-8`.
      #
      # The consequence is worse than it sounds. A cop that raises does not
      # produce a false positive — it produces a *failed run*: RuboCop reports
      # the error, prints "no offenses detected", and exits 1. There is
      # nothing to correct and nothing in the offense list to explain it, so
      # the only way out is to exclude the file. Three cops here had that
      # shape and one of them took a real repository's CI down with it.
      #
      # Skipping is the right answer rather than scrubbing the bytes: every
      # rule that reads a literal's contents is a rule about prose a person
      # reads — a pluralised noun, a conjunction, a rendered time zone. A
      # string that is not valid text in its own encoding is not that, so
      # there is no judgement to make about it.
      module ScannableText
        module_function

        # The string, when a regexp can safely be run against it; nil when it
        # cannot. Written to be used as a guard: `text = scannable(...) or return`.
        def scannable(string)
          string if string.is_a?(String) && string.valid_encoding?
        end
      end
    end
  end
end
