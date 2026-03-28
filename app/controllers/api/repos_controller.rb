module Api
  class ReposController < BaseController
    before_action :require_authentication!, only: [:create]

    # POST /api/repos
    def create
      repo = Repo.create_with_bare_repo!(
        owner: current_user,
        name: params[:name],
        description: params[:description] || "",
        tags: params[:tags] || []
      )
      render json: { repo: full_repo_json(repo) }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      if e.message.include?("has already been taken")
        render json: { error: "Repo name already taken for this owner" }, status: :conflict
      else
        render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    # GET /api/repos/:owner/:name
    def show
      repo = find_repo!
      render json: { repo: full_repo_json(repo) }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Repo not found" }, status: :not_found
    end

    private

    def find_repo!
      owner = User.find_by!(username: params[:owner])
      owner.repos.find_by!(name: params[:name])
    end

    def full_repo_json(repo)
      {
        owner: repo.owner.username,
        name: repo.name,
        description: repo.description,
        tags: repo.tags,
        clone_url: repo.clone_url(request),
        web_url: repo.web_url(request),
        default_branch: "main",
        stars: repo.stars_count,
        created_at: repo.created_at.iso8601,
        last_pushed_at: repo.last_pushed_at&.iso8601
      }
    end
  end
end
