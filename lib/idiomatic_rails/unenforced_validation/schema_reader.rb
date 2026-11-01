# frozen_string_literal: true

require "prism"

module IdiomaticRails
  class UnenforcedValidation
    # Reads db/schema.rb for the two facts a validation can be checked
    # against: which columns are NOT NULL, and which column sets carry a
    # unique index.
    #
    # Parsed rather than loaded. The schema is a literal file, and a check
    # about database constraints should not need the application to boot or a
    # database to exist.
    module SchemaReader
      # @return [Hash] table => { not_null: Set, unique_indexes: Array<Array> }
      def self.call(path)
        return {} unless path.exist?

        tables = Hash.new { |hash, key| hash[key] = { not_null: Set.new, unique_indexes: [] } }

        Prism.parse(path.read).value.breadth_first_search do |node|
          next false unless node.is_a?(Prism::CallNode)

          case node.name
          when :create_table then read_table(node, tables)
          when :add_index then read_add_index(node, tables)
          when :add_unique_constraint then read_add_unique_constraint(node, tables)
          end
          false
        end

        tables
      end

      def self.read_table(node, tables)
        name = string_argument(node, 0)
        return unless name

        entry = tables[name]
        node.block&.body&.breadth_first_search do |child|
          next false unless child.is_a?(Prism::CallNode)

          # A unique index and a unique constraint both enforce the
          # invariant; only the spelling differs, and Rails dumps
          # `t.unique_constraint` for one declared as a constraint.
          if child.name == :index
            columns = array_of_strings(child.arguments&.arguments&.first)
            entry[:unique_indexes] << columns.sort if columns && unique?(child)
          elsif child.name == :unique_constraint
            columns = array_of_strings(child.arguments&.arguments&.first)
            entry[:unique_indexes] << columns.sort if columns
          elsif (column = string_argument(child, 0))
            entry[:not_null] << column if keyword_false?(child, "null")
          end
          false
        end
      end

      def self.read_add_index(node, tables)
        table = string_argument(node, 0)
        columns = array_of_strings(node.arguments&.arguments&.[](1))
        return unless table && columns && unique?(node)

        tables[table][:unique_indexes] << columns.sort
      end

      def self.read_add_unique_constraint(node, tables)
        table = string_argument(node, 0)
        columns = array_of_strings(node.arguments&.arguments&.[](1))
        return unless table && columns

        tables[table][:unique_indexes] << columns.sort
      end

      def self.string_argument(node, index)
        argument = node.arguments&.arguments&.[](index)
        argument.is_a?(Prism::StringNode) ? argument.unescaped : nil
      end

      def self.array_of_strings(node)
        return nil unless node.is_a?(Prism::ArrayNode)

        node.elements.grep(Prism::StringNode).map(&:unescaped)
      end

      def self.unique?(node) = keyword(node, "unique").is_a?(Prism::TrueNode)

      def self.keyword_false?(node, key) = keyword(node, key).is_a?(Prism::FalseNode)

      def self.keyword(node, key)
        hash = node.arguments&.arguments&.grep(Prism::KeywordHashNode)&.first
        return nil unless hash

        pair = hash.elements.find do |element|
          element.is_a?(Prism::AssocNode) && element.key.is_a?(Prism::SymbolNode) &&
            element.key.unescaped == key
        end
        pair&.value
      end
    end
  end
end
