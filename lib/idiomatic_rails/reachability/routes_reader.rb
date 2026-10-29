# frozen_string_literal: true

module IdiomaticRails
  class Reachability
    # Reads controller action names out of config/routes.rb.
    #
    # Only the forms that name their actions are understood. A bare
    # `resources :things` draws seven actions while naming none, so rather
    # than assume the REST set — and quietly exempt a dead action with a
    # standard name — the reader raises and the run fails.
    module RoutesReader
      ACTION_IN_STRING = /["'][\w\/]+#(\w+)["']/
      RESOURCEFUL = %i[resource resources].freeze
      LIMITS = %w[only except].freeze

      def self.call(path)
        source = path.read
        actions = []
        resourceful = false
        limited = false

        Prism.parse(source).value.breadth_first_search do |node|
          next false unless node.is_a?(Prism::CallNode) && RESOURCEFUL.include?(node.name)

          resourceful = true
          node.arguments&.arguments&.each do |argument|
            next unless argument.is_a?(Prism::KeywordHashNode)

            argument.elements.each do |pair|
              next unless pair.is_a?(Prism::AssocNode)
              next unless pair.key.is_a?(Prism::SymbolNode) && LIMITS.include?(pair.key.unescaped)

              limited = true
              actions.concat(pair.value.elements.map(&:unescaped)) if pair.value.respond_to?(:elements)
            end
          end
          false
        end

        if resourceful && !limited
          raise Error, "#{path} draws a resource without `only:`, so its actions cannot be " \
                       "read off the file. Name them, or exempt the actions individually."
        end

        (actions + source.scan(ACTION_IN_STRING).flatten).uniq
      end
    end
  end
end
