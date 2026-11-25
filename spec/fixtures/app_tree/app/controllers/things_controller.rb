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

class RescuingThingsController
  rescue_from StandardError, with: :lifecycle_refused
  rate_limit to: 10, within: 1, by: :rate_limit_client, with: :refuse_request

  def lifecycle_refused = nil
  def rate_limit_client = nil
  def refuse_request = nil
end
