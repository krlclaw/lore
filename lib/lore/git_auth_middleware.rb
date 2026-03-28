module Lore
  # Rack middleware that sits in front of Grack to enforce Lore's git access rules:
  #   - Clone/fetch (git-upload-pack) is anonymous
  #   - Push (git-receive-pack) requires HTTP Basic auth with username + PAT
  #
  # It also resolves the repo path from the URL and sets GRACK env vars.
  class GitAuthMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      path = Rack::Utils.unescape(request.path_info).gsub(%r{/+}, "/")

      # Determine if this is a push (receive-pack) request
      is_push = push_request?(path, request.request_method, request.params)

      if is_push
        user = authenticate(env)
        return unauthorized_response unless user
        # Store authenticated user for post-receive hooks
        env["lore.user"] = user
      end

      @app.call(env)
    end

    private

    def push_request?(path, method, params)
      # POST to git-receive-pack endpoint
      return true if method == "POST" && path.match?(%r{/git-receive-pack$})
      # GET info/refs with service=git-receive-pack (push advertisement)
      return true if method == "GET" && path.match?(%r{/info/refs$}) && params["service"] == "git-receive-pack"
      false
    end

    def authenticate(env)
      auth = Rack::Auth::Basic::Request.new(env)
      return nil unless auth.provided? && auth.basic?

      username, token = auth.credentials
      return nil if username.blank? || token.blank?

      user = User.find_by(username: username)
      return nil unless user&.authenticate_pat(token)

      user
    end

    def unauthorized_response
      [
        401,
        {
          "Content-Type" => "text/plain",
          "WWW-Authenticate" => 'Basic realm="Lore"'
        },
        ["Authentication required"]
      ]
    end
  end
end
