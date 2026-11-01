# frozen_string_literal: true

require "prism"
require "set"
require "active_support/core_ext/string/inflections"
require_relative "unenforced_validation/schema_reader"

module IdiomaticRails
  # Finds `validates` declarations the database does not back.
  #
  # ## Why this is not a cop
  #
  # The answer lives in two files. A cop sees one at a time, so it can read
  # `validates :year, uniqueness: true` and never learn whether a unique
  # index exists. This reads the models and db/schema.rb together.
  #
  # ## Why it matters more than it looks
  #
  # A uniqueness validation is a `SELECT` followed by an `INSERT`, and two
  # requests can both run the `SELECT` before either runs the `INSERT`. The
  # validation is a courtesy to the user; only the index is an invariant.
  # The same holds for `presence: true` against a nullable column — the
  # validation covers the one write path that runs validations, and nothing
  # covers a migration, a backfill, `update_column`, or `insert_all`.
  #
  # ## What it does not do
  #
  #   - conditional validations (`if:`, `unless:`, `on:`) are skipped. They
  #     are deliberately partial, so the database cannot mirror them.
  #   - `scope:` on a uniqueness validation needs a composite index, and the
  #     columns are compared as a set.
  class UnenforcedValidation
    Finding = Struct.new(:model, :line, :attribute, :kind, :remedy, keyword_init: true) do
      def to_s
        "#{model}:#{line}  validates :#{attribute}, #{kind} — #{remedy}"
      end
    end

    DEFAULTS = {
      "model_paths" => %w[app/models],
      "schema_path" => "db/schema.rb"
    }.freeze

    # A validation that only applies sometimes cannot be mirrored by a
    # constraint that always applies.
    CONDITIONAL = %i[if unless on allow_nil allow_blank].freeze

    def initialize(root:, config: {})
      @root = Pathname.new(root)
      @config = DEFAULTS.merge(config || {})
      @exempt = ((config || {})["exemptions"] || []).map { |e| e.fetch("name") }.to_set
    end

    def problems
      findings.reject { |f| @exempt.include?("#{f.model}##{f.attribute}") }.map(&:to_s)
    end

    def validation_count = validations.size

    private

    attr_reader :root, :config

    def findings
      validations.filter_map do |validation|
        case validation[:kind]
        when :uniqueness
          next if unique_index?(validation[:table], validation[:columns])

          finding(validation, "uniqueness: true",
                  "no unique index on #{validation[:table]}(#{validation[:columns].join(', ')})")
        when :presence
          next if not_null?(validation[:table], validation[:attribute])

          finding(validation, "presence: true",
                  "#{validation[:table]}.#{validation[:attribute]} is nullable")
        end
      end
    end

    def finding(validation, kind, remedy)
      Finding.new(model: validation[:model], line: validation[:line],
                  attribute: validation[:attribute], kind: kind, remedy: remedy)
    end

    def validations
      @validations ||= model_files.flat_map { |path| read_validations(path) }
    end

    def read_validations(path)
      table = table_for(path)
      found = []

      Prism.parse(path.read).value.breadth_first_search do |node|
        next false unless node.is_a?(Prism::CallNode) && node.name == :validates
        next false if node.arguments.nil?

        attributes = node.arguments.arguments.select { |a| a.is_a?(Prism::SymbolNode) }
        options = node.arguments.arguments.grep(Prism::KeywordHashNode).first
        next false if options.nil? || conditional?(options)

        %i[uniqueness presence].each do |kind|
          next unless enabled?(options, kind)

          attributes.each do |attribute|
            found << {
              model: relative(path), line: node.location.start_line, table: table,
              attribute: attribute.unescaped, kind: kind,
              columns: ([ attribute.unescaped ] + scope_columns(options)).sort
            }
          end
        end
        false
      end

      found
    end

    def conditional?(options)
      options.elements.any? do |pair|
        pair.is_a?(Prism::AssocNode) && pair.key.is_a?(Prism::SymbolNode) &&
          CONDITIONAL.include?(pair.key.unescaped.to_sym)
      end
    end

    def enabled?(options, kind)
      options.elements.any? do |pair|
        next false unless pair.is_a?(Prism::AssocNode) && pair.key.is_a?(Prism::SymbolNode)
        next false unless pair.key.unescaped.to_sym == kind

        !pair.value.is_a?(Prism::FalseNode)
      end
    end

    # `uniqueness: { scope: :year }` needs a composite index.
    def scope_columns(options)
      pair = options.elements.find do |element|
        element.is_a?(Prism::AssocNode) && element.key.is_a?(Prism::SymbolNode) &&
          element.key.unescaped == "uniqueness" && element.value.is_a?(Prism::HashNode)
      end
      return [] unless pair

      scope = pair.value.elements.find do |element|
        element.is_a?(Prism::AssocNode) && element.key.is_a?(Prism::SymbolNode) &&
          element.key.unescaped == "scope"
      end
      return [] unless scope

      case scope.value
      when Prism::SymbolNode then [ scope.value.unescaped ]
      when Prism::ArrayNode then scope.value.elements.grep(Prism::SymbolNode).map(&:unescaped)
      else []
      end
    end

    def unique_index?(table, columns)
      schema.dig(table, :unique_indexes)&.any? { |index| index == columns.sort } || false
    end

    def not_null?(table, column)
      schema.dig(table, :not_null)&.include?(column) || false
    end

    # Parsed with a reader rather than by loading Rails: the schema is a
    # literal file, and this check should not need the application to boot.
    def schema
      @schema ||= SchemaReader.call(root.join(config["schema_path"]))
    end

    def model_files
      config["model_paths"].flat_map { |dir| Pathname.glob(root.join(dir, "**/*.rb")).sort }
    end

    # ActiveRecord's default: the pluralised, underscored class name.
    def table_for(path)
      relative(path).sub(%r{\Aapp/models/}, "").sub(/\.rb\z/, "").tr("/", "_")
                    .then { |name| ActiveSupport::Inflector.pluralize(name) }
    end

    def relative(path) = path.relative_path_from(root).to_s
  end
end
