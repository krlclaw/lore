module Api
  class UsersController < BaseController
    # POST /api/users
    def create
      user = User.create_with_pat(username: params[:username])
      render json: {
        user: {
          username: user.username,
          created_at: user.created_at.iso8601
        },
        pat: user.plaintext_pat
      }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      if e.message.include?("has already been taken")
        render json: { error: "Username already taken" }, status: :conflict
      else
        render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    # GET /api/users/:username
    def show
      user = User.find_by!(username: params[:username])
      repos = user.repos
      render json: {
        user: {
          username: user.username,
          repos_count: repos.count,
          total_stars: repos.sum(:stars_count),
          created_at: user.created_at.iso8601
        }
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "User not found" }, status: :not_found
    end

    # GET /api/users/:username/repos
    def repos
      user = User.find_by!(username: params[:username])
      repos = user.repos.order(
        Arel.sql("CASE WHEN last_pushed_at IS NULL THEN 1 ELSE 0 END, last_pushed_at DESC, created_at DESC")
      )
      render json: {
        repos: repos.map { |r| repo_json(r) }
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "User not found" }, status: :not_found
    end

    private

    def repo_json(repo)
      {
        owner: repo.owner.username,
        name: repo.name,
        description: repo.description,
        tags: repo.tags,
        clone_url: repo.clone_url(request),
        stars: repo.stars_count,
        last_pushed_at: repo.last_pushed_at&.iso8601
      }
    end
  end
end
