# frozen_string_literal: true

class Thing
  REACHED_CONSTANT = 1
  DEAD_CONSTANT = 2

  def initialize(name)
    @name = name
  end

  def ==(other)
    other.is_a?(Thing)
  end

  def reached_from_a_sibling
    REACHED_CONSTANT
  end

  def reached_only_by_the_spec
    :dead
  end

  def reached_by_a_block_argument
    :alive
  end
end

class PermittedThing
  def permitted_writer=(value)
    @permitted_writer = value
  end
end

class CallbackThing
  before_validation :validated_by_callback
  before_create :created_by_callback

  def validated_by_callback = nil
  def created_by_callback = nil
end
