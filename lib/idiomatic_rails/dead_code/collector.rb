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
          if argument.is_a?(Prism::SymbolNode)
            collect_dispatched_symbol(node, argument)
          elsif COMPUTED_DISPATCH.include?(node.name)
            @computed_dispatch << @path
          end
        end
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
