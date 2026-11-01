# frozen_string_literal: true

class ThingsController < ApplicationController
  def index
    @things = []
  end

  private

  def thing_params
    params.require(:thing).permit(:permitted_writer)
  end
end
