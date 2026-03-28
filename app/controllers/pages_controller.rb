class PagesController < ApplicationController
  # GET /
  def home
    @featured_repos = Repo.includes(:owner, :stars)
      .order(stars_count: :desc, created_at: :desc)
      .limit(6)
    @recent_repos = Repo.includes(:owner, :stars).order(
      Arel.sql("CASE WHEN last_pushed_at IS NULL THEN 1 ELSE 0 END, last_pushed_at DESC, created_at DESC")
    ).limit(6)
    @repo_count = Repo.count
    @user_count = User.count
    @star_count = Star.count
  end

  # GET /search
  def search
    @query = params[:q].to_s.strip
    @repos = []

    if @query.present? && ENV["OPENAI_API_KEY"].present?
      query_embedding = Lore::EmbeddingService.embed(@query)
      all_repos = Repo.where.not(embedding: nil).includes(:owner, :stars)

      scored = all_repos.map do |repo|
        score = Lore::EmbeddingService.cosine_similarity(query_embedding, repo.embedding_vector)
        [repo, score]
      end

      @repos = scored.sort_by { |_, s| -s }.first(10)
    end
  end

  # GET /getting-started
  def getting_started
  end
end
