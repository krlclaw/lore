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
    @star_count = Repo.sum(:stars_count)
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

      top = scored.sort_by { |_, s| -s }.first(10)

      # Normalize scores so top result shows ~95% and others scale proportionally.
      # Raw cosine similarity often looks unimpressively low (30-50%).
      if top.any?
        max_score = top.first[1]
        min_score = top.last[1]
        @repos = top.map do |repo, raw|
          normalized = if max_score == min_score
            0.95
          else
            0.70 + 0.25 * ((raw - min_score) / (max_score - min_score))
          end
          [repo, normalized]
        end
      else
        @repos = top
      end
    end
  end

  # GET /getting-started
  def getting_started
  end

  # GET /bin/lore — serve CLI script for curl-based install
  def cli_download
    cli_path = Rails.root.join("bin", "lore")
    send_file cli_path, type: "text/plain", disposition: "inline", filename: "lore"
  end
end
