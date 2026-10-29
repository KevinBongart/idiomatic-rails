# frozen_string_literal: true

# The gem is `idiomatic-rails`, but its constants live under `IdiomaticRails`
# rather than `Idiomatic::Rails`. Nesting a module called `Rails` would mean
# that inside it, a bare `Rails` resolves to this gem instead of the
# framework — a trap for every file in the gem and for anyone reading one.
require_relative "idiomatic_rails"
