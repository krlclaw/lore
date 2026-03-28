module Api
  class ReposController < BaseController
    before_action :require_authentication!, only: [:create, :star, :unstar]

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

    # GET /api/repos/search?q=...
    def search
      query = params[:q].to_s.strip
      return render(json: { error: "Query parameter q is required" }, status: :bad_request) if query.blank?

      unless ENV["OPENAI_API_KEY"].present?
        return render(json: { error: "Embeddings not configured" }, status: :service_unavailable)
      end

      query_embedding = Lore::EmbeddingService.embed(query)
      repos = Repo.where.not(embedding: nil).includes(:owner, :stars)

      scored = repos.map do |repo|
        score = Lore::EmbeddingService.cosine_similarity(query_embedding, repo.embedding_vector)
        [repo, score]
      end

      top = scored.sort_by { |_, score| -score }.first(10)

      render json: {
        query: query,
        repos: top.map { |repo, score| search_result_json(repo, score) }
      }
    rescue => e
      Rails.logger.error("Search error: #{e.message}")
      render json: { error: "Search failed" }, status: :internal_server_error
    end

    # POST /api/repos/:owner/:name/star
    def star
      repo = find_repo!
      Star.find_or_create_by!(user: current_user, repo: repo)
      render json: {
        repo: { owner: repo.owner.username, name: repo.name, stars: repo.stars_count },
        starred: true
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Repo not found" }, status: :not_found
    end

    # DELETE /api/repos/:owner/:name/star
    def unstar
      repo = find_repo!
      Star.find_by(user: current_user, repo: repo)&.destroy
      render json: {
        repo: { owner: repo.owner.username, name: repo.name, stars: repo.stars_count },
        starred: false
      }
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

    def search_result_json(repo, score)
      {
        owner: repo.owner.username,
        name: repo.name,
        description: repo.description,
        tags: repo.tags,
        clone_url: repo.clone_url(request),
        stars: repo.stars_count,
        last_pushed_at: repo.last_pushed_at&.iso8601,
        similarity_score: score.round(4)
      }
    end
  end
end
