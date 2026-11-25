# frozen_string_literal: true

module IdiomaticRails
  class DeadCode
    # Gathers every way one piece of source can name another.
    class Collector < Prism::Visitor
      attr_reader :calls, :constants, :symbol_arguments, :computed_dispatch

      # Dispatchers are injected rather than read from a constant: the
      # application's own Rails supplies its callback macros.
      def initialize(dispatchers: DeadCode::SYMBOL_DISPATCHERS)
        @dispatchers = dispatchers.to_set
        @calls = []
        @constants = []
        @symbol_arguments = []
        @computed_dispatch = []
        @path = nil
        super()
      end

      def for_path(path)
        @path = path
        self
      end

      def visit_call_node(node)
        @calls << node.name.to_s
        collect_block_symbol(node)
        collect_argument_symbols(node)
        super
      end

      def visit_constant_read_node(node)
        @constants << node.name.to_s
        super
      end

      def visit_constant_path_node(node)
        @constants << node.name.to_s if node.name
        super
      end

      private

      # `sort_by(&:settlement_rank)` is a reference, and the symbol lives in
      # the block argument rather than in the argument list.
      def collect_block_symbol(node)
        block = node.block
        return unless block.is_a?(Prism::BlockArgumentNode)
        return unless block.expression.is_a?(Prism::SymbolNode)

        @symbol_arguments << block.expression.unescaped
      end

      def collect_argument_symbols(node)
        node.arguments&.arguments&.each do |argument|
          case argument
          when Prism::SymbolNode
            collect_dispatched_symbol(node, argument)
          when Prism::KeywordHashNode, Prism::HashNode
            collect_option_symbols(node, argument)
          else
            @computed_dispatch << @path if COMPUTED_DISPATCH.include?(node.name)
          end
        end
      end

      # `before_save :sync, if: :became_spam?` names two methods, not one.
      # The second lives in an option value, and Rails sends it just the same.
      #
      # Nested because the option can be one level in:
      # `validates :password, confirmation: { if: :password_required? }`
      # puts the condition inside the validator's own options hash.
      def collect_option_symbols(node, hash)
        return unless @dispatchers.include?(node.name)

        hash.elements.each do |element|
          next unless element.is_a?(Prism::AssocNode)

          value = element.value
          case value
          when Prism::KeywordHashNode, Prism::HashNode
            collect_option_symbols(node, value)
          when Prism::SymbolNode
            next unless option_names_a_method?(element.key)

            @symbol_arguments << value.unescaped
          end
        end
      end

      def option_names_a_method?(key)
        key.is_a?(Prism::SymbolNode) && METHOD_NAMING_OPTIONS.include?(key.unescaped.to_sym)
      end

      def collect_dispatched_symbol(node, argument)
        return unless @dispatchers.include?(node.name)

        name = argument.unescaped
        @symbol_arguments << name
        # `permit(:start_time)` is what reaches `def start_time=`: mass
        # assignment writes through the setter, and the permitted name never
        # carries the `=`. Without this the writers an application permits
        # read as dead, which is three of them in one model here.
        @symbol_arguments << "#{name}=" if ATTRIBUTE_ASSIGNERS.include?(node.name)
      end
    end
  end
end
