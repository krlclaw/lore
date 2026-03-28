require "grack/app"
require "lore/git_auth_middleware"

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
        get ":owner/:name", action: :show, as: :show,
          constraints: { owner: /[a-z][a-z0-9-]*/, name: /[a-z][a-z0-9-]*/ }
      end
    end
  end

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
