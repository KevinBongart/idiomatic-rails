# frozen_string_literal: true

# Stands in for a spec file: it reaches the dead method, and that must not
# count as the method being used.
Thing.new("x").reached_only_by_the_spec
Thing::DEAD_CONSTANT
