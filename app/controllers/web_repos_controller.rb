class WebReposController < ApplicationController
  # GET /:owner/:name
  def show
    @owner = User.find_by!(username: params[:owner])
    @repo = @owner.repos.includes(:stars).find_by!(name: params[:name])
    @readme = read_readme(@repo)
  rescue ActiveRecord::RecordNotFound
    render plain: "Not found", status: :not_found
  end

  # GET /:owner
  def owner
    @owner = User.find_by!(username: params[:owner])
    @repos = @owner.repos.includes(:stars).order(
      Arel.sql("CASE WHEN last_pushed_at IS NULL THEN 1 ELSE 0 END, last_pushed_at DESC, created_at DESC")
    )
  rescue ActiveRecord::RecordNotFound
    render plain: "Not found", status: :not_found
  end

  private

  def read_readme(repo)
    return nil unless File.directory?(repo.path)
    raw = `git -C #{Shellwords.escape(repo.path)} show HEAD:README.md 2>/dev/null`
    return nil if raw.blank?

    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, link_attributes: { target: "_blank" })
    markdown = Redcarpet::Markdown.new(renderer,
      fenced_code_blocks: true,
      tables: true,
      autolink: true,
      strikethrough: true,
      no_intra_emphasis: true
    )
    markdown.render(raw).html_safe
  rescue
    nil
  end
end
