require "grack/app"
require "lore/git_auth_middleware"

# Reserved top-level paths that must not be captured by the :owner route
RESERVED_PATHS = %w[api git up search home getting-started rails assets].freeze
OWNER_CONSTRAINT = lambda { |req| !RESERVED_PATHS.include?(req.params[:owner]) }

Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # JSON API
  namespace :api do
    resources :users, only: [:create], param: :username do
      get :repos, on: :member
    end
    resources :repos, only: [:create] do
      collection do
        get "search", action: :search
        get ":owner/:name", action: :show, as: :show,
          constraints: { owner: /[a-z][a-z0-9-]*/, name: /[a-z][a-z0-9-]*/ }
        post ":owner/:name/star", action: :star,
          constraints: { owner: /[a-z][a-z0-9-]*/, name: /[a-z][a-z0-9-]*/ }
        delete ":owner/:name/star", action: :unstar,
          constraints: { owner: /[a-z][a-z0-9-]*/, name: /[a-z][a-z0-9-]*/ }
      end
    end
  end

  # Web UI — static routes first
  root "pages#home"
  get "search" => "pages#search"
  get "getting-started" => "pages#getting_started"

  # Web UI — dynamic forge routes (must be after static routes)
  get ":owner/:name" => "web_repos#show",
    constraints: { owner: /[a-z][a-z0-9-]*/, name: /[a-z][a-z0-9-]*/ }
  get ":owner" => "web_repos#owner",
    constraints: OWNER_CONSTRAINT

  # Git Smart HTTP transport via Grack
  grack = Grack::App.new(
    root: Rails.application.config.lore_repo_root,
    allow_pull: true,
    allow_push: true  # Auth is enforced by GitAuthMiddleware, not Grack
  )
  git_stack = Rack::Builder.new do
    use Lore::GitAuthMiddleware
    run grack
  end
  mount git_stack => "/git"
end
