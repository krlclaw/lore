module Api
  class BaseController < ActionController::API
    include ApiAuthentication
    include RateLimiting

    rescue_from ActiveRecord::RecordNotFound do |e|
      render json: { error: "Not found", details: e.message }, status: :not_found
    end

    rescue_from ActionController::ParameterMissing do |e|
      render json: { error: "Missing parameter", details: e.message }, status: :bad_request
    end
  end
end
