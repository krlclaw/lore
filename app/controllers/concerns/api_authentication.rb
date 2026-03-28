module ApiAuthentication
  extend ActiveSupport::Concern

  private

  def current_user
    @current_user ||= authenticate_bearer_token
  end

  def require_authentication!
    unless current_user
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def authenticate_bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")

    token = header.split(" ", 2).last
    return nil if token.blank?

    User.find_each do |user|
      return user if user.authenticate_pat(token)
    end
    nil
  end
end
