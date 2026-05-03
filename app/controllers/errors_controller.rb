class ErrorsController < ApplicationController
  layout "application"

  # Skip CSRF: error renders are read-only. Without this skip,
  # exceptions_app dispatch on a non-GET request that hits a 404 path
  # would 422 itself trying to verify a token that no error path would
  # naturally carry.
  skip_before_action :verify_authenticity_token

  def show
    @code = params[:code].to_i
    @code = 404 unless [ 400, 404, 406, 422, 500 ].include?(@code)
    render :show, status: @code
  end
end
