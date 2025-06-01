class ApplicationController < ActionController::API
  rescue_from StandardError, with: :handle_error

  private

  def handle_error(error)
    render json: { error: error.message }, status: :internal_server_error
  end
end
