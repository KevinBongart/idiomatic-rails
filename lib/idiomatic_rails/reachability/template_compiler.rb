# frozen_string_literal: true

require "action_view"

module IdiomaticRails
  class Reachability
    # Compiles an ERB template to the Ruby that Rails renders, so a helper
    # called only from a view is reachable and needs no exemption.
    module TemplateCompiler
      # ActionView's Erubi subclass rather than plain Erubi, which cannot
      # compile the `<%= ... do %>` block form.
      #
      # Wrapped in a method definition because a compiled layout contains a
      # bare `yield`, which is a syntax error at the top level.
      def self.call(path)
        src = ActionView::Template::Handlers::ERB::Erubi.new(path.read).src
        "def __template__\n#{src}\nend"
      end
    end
  end
end
