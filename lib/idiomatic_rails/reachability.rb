# frozen_string_literal: true

require "prism"
require "yaml"
require "set"

module IdiomaticRails
  # Finds methods and constants that nothing but their own spec reaches.
  #
  # ## Why not coverage
  #
  # A dead method keeps its spec, so it stays covered. The method this was
  # extracted from was exercised by an example asserting its return value
  # right up to the commit that deleted it, and the project's coverage floor
  # never moved. What marks code dead is that *only* the test suite reaches
  # it — so this counts references from everywhere except the spec
  # directory, and says nothing about coverage.
  #
  # ## Why a parser
  #
  # A textual sweep cannot tell `result[:label]`, a `label:` hash key, the
  # word "label" in a comment, and a call to `label` apart. In the
  # application this came from, a grep-based sweep pronounced the tree clean
  # and the parser then found three more dead methods in it — one of them
  # hidden because `compute_for_member` contains `for_member`.
  #
  # ## What it cannot see
  #
  #   - a method reached through a name computed at runtime. Each such call
  #     site must be recorded, with what it targets, or the run fails.
  #   - dead code still called by other dead code. The cluster's entry point
  #     is reported; the rest surfaces on the next run.
  #   - anything that is not a method or a constant.
  class Reachability
    Finding = Struct.new(:kind, :name, :path, :line, keyword_init: true)

    DEFAULTS = {
      "definition_paths" => %w[app lib],
      "reference_paths" => %w[app lib config bin Rakefile],
      "template_paths" => %w[app/views],
      "test_paths" => %w[spec test],
      "protocol_methods" => %w[
        initialize == eql? hash <=> to_s to_str inspect coerce
        method_missing respond_to_missing?
      ],
      "routes_file" => "config/routes.rb"
    }.freeze

    # Calls that name a method with a symbol, so the symbol is a reference.
    #
    # A named list, and it has to be: counting *every* symbol argument makes
    # `row[:total_minutes]` look like a call to `total_minutes`, which is how
    # the first version of this missed a deliberately re-added dead method.
    # A dispatcher nobody listed yields a false finding rather than a silent
    # pass, which is the right direction to be wrong in.
    SYMBOL_DISPATCHERS = %i[
      send public_send __send__ method respond_to? alias_method define_method
      delegate private_class_method public_class_method private_constant
      helper_method before_action after_action around_action
      skip_before_action rescue_from validate validates before_validation
      after_commit after_save before_save scope
    ].freeze

    COMPUTED_DISPATCH = %i[send public_send __send__].freeze

    def initialize(root:, config: {})
      @root = Pathname.new(root)
      @config = DEFAULTS.merge(config || {})
      @exemptions = @config["exemptions"] || {}
    end

    # @return [Array<String>] problems, empty when the tree is clean
    def problems
      @problems ||= unclaimed_findings + stale_exemptions + dispatch_problems
    end

    def definition_count
      definitions.size
    end

    private

    attr_reader :root, :config

    def unclaimed_findings
      findings.reject { |f| exempt_names.include?(f.name) }.map do |f|
        "#{f.path}:#{f.line}  #{f.kind} #{f.name} is defined and never referenced outside the tests"
      end
    end

    def stale_exemptions
      (exempt_names - findings.map(&:name)).map do |name|
        "'#{name}' is exempt but is reached now — delete the entry"
      end
    end

    def dispatch_problems
      found = collector.computed_dispatch.uniq.sort
      recorded = (@exemptions["computed_dispatch"] || []).map { |e| e.fetch("file") }

      (found - recorded).map do |file|
        "#{file} dispatches on a computed name, so this scan cannot see what it reaches. " \
        "Read it and record what it targets under computed_dispatch."
      end + (recorded - found).map do |file|
        "#{file} no longer dispatches on a computed name — delete the entry"
      end
    end

    def exempt_names
      @exempt_names ||= (@exemptions["exempt"] || []).map { |e| e.fetch("name") }.to_set
    end

    def findings
      @findings ||= definitions.reject do |definition|
        config["protocol_methods"].include?(definition.name) ||
          referenced.include?(definition.name) ||
          routed_action?(definition)
      end
    end

    def referenced
      @referenced ||=
        (collector.calls + collector.constants + collector.symbol_arguments).to_set
    end

    def definitions
      @definitions ||= ruby_files(config["definition_paths"]).flat_map do |path|
        collect_definitions(path)
      end
    end

    def collect_definitions(path)
      found = []
      parse(path.read, path).breadth_first_search do |node|
        case node
        when Prism::DefNode
          found << Finding.new(kind: "method", name: node.name.to_s,
                               path: relative(path), line: node.location.start_line)
        when Prism::ConstantWriteNode
          if node.name.to_s.match?(/\A[A-Z][A-Z0-9_]*\z/)
            found << Finding.new(kind: "constant", name: node.name.to_s,
                                 path: relative(path), line: node.location.start_line)
          end
        end
        false
      end
      found
    end

    def collector
      @collector ||= Collector.new.tap do |c|
        ruby_files(config["reference_paths"]).each do |path|
          parse(path.read, path).accept(c.for_path(relative(path)))
        end
        template_files.each do |path|
          parse(TemplateCompiler.call(path), path).accept(c.for_path(relative(path)))
        end
      end
    end

    # Rails calls a controller action; nothing in the application does. The
    # names are read off the routes file rather than from a rule like "every
    # public method of a controller", which would exempt a genuinely dead one.
    def routed_actions
      @routed_actions ||= begin
        file = root.join(config["routes_file"])
        file.exist? ? RoutesReader.call(file) : []
      end
    end

    def routed_action?(definition)
      definition.path.match?(%r{\Aapp/controllers/.*_controller\.rb\z}) &&
        routed_actions.include?(definition.name)
    end

    def ruby_files(paths)
      paths.flat_map do |entry|
        target = root.join(entry)
        if target.file?
          [ target ]
        else
          Pathname.glob(target.join("**/*.{rb,rake}")).sort
        end
      end.reject { |path| test_path?(path) }
    end

    def template_files
      config["template_paths"].flat_map { |entry| Pathname.glob(root.join(entry, "**/*.erb")).sort }
    end

    def test_path?(path)
      config["test_paths"].any? { |dir| relative(path).start_with?("#{dir}/") }
    end

    def relative(path)
      path.relative_path_from(root).to_s
    end

    def parse(source, origin)
      result = Prism.parse(source)
      raise Error, "could not parse #{origin}" if result.failure?

      result.value
    end

    Error = Class.new(StandardError)
  end
end

require_relative "reachability/collector"
require_relative "reachability/routes_reader"
require_relative "reachability/template_compiler"
