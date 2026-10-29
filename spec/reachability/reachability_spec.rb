# frozen_string_literal: true

require "spec_helper"

RSpec.describe IdiomaticRails::Reachability do
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

  describe "a routes file it cannot read" do
    around do |example|
      path = File.join(root, "config/routes.rb")
      original = File.read(path)
      File.write(path, "Rails.application.routes.draw do\n  resources :things\nend\n")
      example.run
    ensure
      File.write(path, original)
    end

    # Guessing the REST set would quietly exempt a dead action with a
    # standard name, so it refuses instead.
    it "raises rather than assuming the REST actions" do
      expect { problems }.to raise_error(described_class::Error, /without `only:`/)
    end
  end
end
