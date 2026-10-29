# frozen_string_literal: true

class Caller
  def run(things)
    things.map(&:reached_by_a_block_argument)
    Thing.new("x").reached_from_a_sibling
  end
end
