# frozen_string_literal: true

module IdiomaticRails
  class Reachability
    # Gathers every way one piece of source can name another.
    class Collector < Prism::Visitor
      attr_reader :calls, :constants, :symbol_arguments, :computed_dispatch

      def initialize
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
            @symbol_arguments << argument.unescaped if SYMBOL_DISPATCHERS.include?(node.name)
          elsif COMPUTED_DISPATCH.include?(node.name)
            @computed_dispatch << @path
          end
        end
      end
    end
  end
end
