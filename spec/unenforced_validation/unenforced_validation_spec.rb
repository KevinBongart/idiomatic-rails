# frozen_string_literal: true

require "spec_helper"

RSpec.describe IdiomaticRails::UnenforcedValidation do
  let(:root) { File.expand_path("../fixtures/validation_tree", __dir__) }

  def problems(config = {}) = described_class.new(root: root, config: config).problems

  it "accepts a uniqueness validation backed by a unique index" do
    expect(problems).not_to include(a_string_matching(/:email, uniqueness/))
  end

  it "accepts a presence validation backed by NOT NULL" do
    expect(problems).not_to include(a_string_matching(/:email, presence/))
  end

  it "reports a presence validation on a nullable column" do
    expect(problems).to include(a_string_matching(/:nickname, presence.*nullable/))
  end

  it "reports a uniqueness validation with no index" do
    expect(problems).to include(a_string_matching(/:handle, uniqueness.*no unique index/))
  end

  # A unique constraint and a unique index both enforce the invariant; Rails
  # dumps the first as `t.unique_constraint`.
  it "accepts a scoped uniqueness backed by a unique constraint" do
    expect(problems).not_to include(a_string_matching(/:slot, uniqueness/))
  end

  # A validation that only applies sometimes cannot be mirrored by a
  # constraint that always applies.
  it "skips a conditional validation" do
    expect(problems).not_to include(a_string_matching(/:note/))
  end

  it "accepts an exemption and counts what it checked" do
    exempt = { "exemptions" => [ { "name" => "app/models/account.rb#handle", "reason" => "x" } ] }
    expect(problems(exempt)).not_to include(a_string_matching(/:handle/))
    expect(described_class.new(root: root).validation_count).to be_positive
  end
end
