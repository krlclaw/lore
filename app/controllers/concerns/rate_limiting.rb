module RateLimiting
  extend ActiveSupport::Concern

  included do
    before_action :enforce_rate_limit
    after_action :set_rate_limit_headers
  end

  private

  RATE_LIMIT = 60         # requests per window
  RATE_WINDOW = 60        # seconds

  def rate_limit_key
    id = defined?(@current_user) && @current_user ? "user:#{@current_user.id}" : "ip:#{request.remote_ip}"
    "rate_limit:#{id}"
  end

  def enforce_rate_limit
    key = rate_limit_key
    count = Rails.cache.read(key).to_i

    if count >= RATE_LIMIT
      response.headers["Retry-After"] = RATE_WINDOW.to_s
      response.headers["X-RateLimit-Limit"] = RATE_LIMIT.to_s
      response.headers["X-RateLimit-Remaining"] = "0"
      render json: { error: "Rate limit exceeded. Try again in #{RATE_WINDOW}s." }, status: :too_many_requests
    else
      Rails.cache.write(key, count + 1, expires_in: RATE_WINDOW.seconds)
    end
  end

  def set_rate_limit_headers
    count = Rails.cache.read(rate_limit_key).to_i
    remaining = [RATE_LIMIT - count, 0].max
    response.headers["X-RateLimit-Limit"] = RATE_LIMIT.to_s
    response.headers["X-RateLimit-Remaining"] = remaining.to_s
  end
end
