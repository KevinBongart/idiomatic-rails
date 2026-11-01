# frozen_string_literal: true

require "spec_helper"

RSpec.describe IdiomaticRails::DeadCode do
  let(:root) { File.expand_path("../fixtures/app_tree", __dir__) }

  def problems(config = {})
    described_class.new(root: root, config: config).problems
  end

  describe "what it reports" do
    it "reports a method only the spec reaches" do
      expect(problems).to include(a_string_matching(/reached_only_by_the_spec/))
    end

    it "reports a constant only the spec reaches" do
      expect(problems).to include(a_string_matching(/constant DEAD_CONSTANT/))
    end

    it "says where the finding is" do
      expect(problems).to include(a_string_matching(%r{app/models/thing\.rb:\d+}))
    end
  end

  describe "what it must not report" do
    it "leaves a method reached from a sibling class alone" do
      expect(problems).not_to include(a_string_matching(/reached_from_a_sibling/))
    end

    # The one a grep-based sweep gets wrong in the other direction: the only
    # reference is `&:name` in a block argument.
    it "leaves a method reached only by a block argument alone" do
      expect(problems).not_to include(a_string_matching(/reached_by_a_block_argument/))
    end

    # Needs the template to compile, including its `<%= ... do %>` block.
    it "leaves a helper called only from a template alone" do
      expect(problems).not_to include(a_string_matching(/only_called_from_a_template/))
    end

    it "leaves a routed controller action alone" do
      expect(problems).not_to include(a_string_matching(/method index/))
    end

    it "leaves protocol methods alone" do
      expect(problems).not_to include(a_string_matching(/method (initialize|==)/))
    end

    it "leaves a constant the application reads alone" do
      expect(problems).not_to include(a_string_matching(/REACHED_CONSTANT/))
    end
  end

  describe "exemptions" do
    let(:exempt) do
      { "exemptions" => { "exempt" => [ { "name" => "reached_only_by_the_spec", "reason" => "x" } ] } }
    end

    it "accepts a finding that is recorded" do
      expect(problems(exempt)).not_to include(a_string_matching(/reached_only_by_the_spec/))
    end

    # The half that stops the file filling up with names nobody rechecks.
    it "reports an exemption that is no longer needed" do
      stale = { "exemptions" => { "exempt" => [ { "name" => "reached_from_a_sibling", "reason" => "x" } ] } }

      expect(problems(stale)).to include(a_string_matching(/is exempt but is reached now/))
    end
  end

  describe "refusing to be unsound" do
    around do |example|
      path = File.join(root, "app/models/dispatcher.rb")
      File.write(path, "class Dispatcher\n  def run(name)\n    send(name)\n  end\nend\n")
      example.run
    ensure
      FileUtils.rm_f(path)
    end

    it "reports a computed dispatch nobody recorded" do
      expect(problems).to include(a_string_matching(/dispatches on a computed name/))
    end

    it "accepts one that is recorded" do
      recorded = { "exemptions" => {
        "computed_dispatch" => [ { "file" => "app/models/dispatcher.rb", "reason" => "x" } ]
      } }

      expect(problems(recorded)).not_to include(a_string_matching(/dispatches on a computed name/))
    end
  end

  describe "callback macros" do
    around do |example|
      path = File.join(root, "bin/rails")
      original = File.read(path)
      # Only before_validation is published here, so before_create must stop
      # being understood — proving the set comes from the application rather
      # than from a constant in this gem.
      File.write(path, <<~STUB)
        #!/usr/bin/env ruby
        puts "ROUTE things#index"
        puts "CALLBACK before_validation"
      STUB
      File.chmod(0o755, path)
      example.run
    ensure
      File.write(path, original)
      File.chmod(0o755, path)
    end

    it "understands a macro the application publishes" do
      expect(problems).not_to include(a_string_matching(/validated_by_callback/))
    end

    it "does not understand one it does not publish" do
      expect(problems).to include(a_string_matching(/created_by_callback/))
    end
  end

  describe "attribute writers" do
    # Mass assignment writes through the setter, and the permitted name never
    # carries the `=`, so the permit list is what reaches it.
    it "treats a permitted attribute as reaching its writer" do
      expect(problems).not_to include(a_string_matching(/permitted_writer=/))
    end
  end

  describe "routes it cannot read" do
    around do |example|
      path = File.join(root, "bin/rails")
      original = File.read(path)
      File.write(path, "#!/usr/bin/env ruby\nwarn 'boot failed: missing credential'\nexit 1\n")
      File.chmod(0o755, path)
      example.run
    ensure
      File.write(path, original)
      File.chmod(0o755, path)
    end

    # Silently treating an unreadable router as "nothing is routed" would
    # report every action in the application as dead. Refusing is the only
    # answer that cannot be mistaken for a result.
    it "raises rather than reporting every action as dead" do
      expect { problems }.to raise_error(described_class::Error, /Could not read the routes/)
    end

    it "says why, including what the boot printed" do
      expect { problems }.to raise_error(described_class::Error, /missing credential/)
    end
  end

  describe "routes drawn by a resourceful macro" do
    around do |example|
      path = File.join(root, "bin/rails")
      original = File.read(path)
      # The router expands `resources :things` itself, so the reader sees the
      # seven actions without having to know the macro exists.
      File.write(path, <<~STUB)
        #!/usr/bin/env ruby
        puts "ROUTE things#index"
        puts "ROUTE things#show"
        puts "ROUTE things#create"
      STUB
      File.chmod(0o755, path)
      example.run
    ensure
      File.write(path, original)
      File.chmod(0o755, path)
    end

    it "exempts an action the macro draws" do
      expect(problems).not_to include(a_string_matching(/method index/))
    end
  end

  describe "matching an action to its own controller" do
    around do |example|
      path = File.join(root, "bin/rails")
      original = File.read(path)
      # A routed `index` on some *other* controller must not exempt this one.
      File.write(path, "#!/usr/bin/env ruby\nputs 'ROUTE widgets#index'\n")
      File.chmod(0o755, path)
      example.run
    ensure
      File.write(path, original)
      File.chmod(0o755, path)
    end

    it "does not exempt an action because another controller routes the name" do
      expect(problems).to include(a_string_matching(/method index/))
    end
  end
end
