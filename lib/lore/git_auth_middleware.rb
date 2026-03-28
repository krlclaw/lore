module Lore
  # Rack middleware that sits in front of Grack to enforce Lore's git access rules:
  #   - Clone/fetch (git-upload-pack) is anonymous
  #   - Push (git-receive-pack) requires HTTP Basic auth with username + PAT
  #   - Successful pushes update last_pushed_at on the repo record
  class GitAuthMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      path = Rack::Utils.unescape(request.path_info).gsub(%r{/+}, "/")

      # Determine if this is a push (receive-pack) request
      is_push = push_request?(path, request.request_method, request.params)
      is_receive_pack_post = (request.request_method == "POST" && path.match?(%r{/git-receive-pack$}))

      if is_push
        user = authenticate(env)
        return unauthorized_response unless user
        env["lore.user"] = user
      end

      status, headers, body = @app.call(env)

      # After a successful receive-pack POST, update last_pushed_at
      if is_receive_pack_post && status == 200
        update_last_pushed_at(path)
      end

      [ status, headers, body ]
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

    def update_last_pushed_at(path)
      # Extract owner/name from path like /testuser/test-repo.git/git-receive-pack
      match = path.match(%r{/([^/]+)/([^/]+?)(?:\.git)?/git-receive-pack$})
      return unless match

      owner_name, repo_name = match[1], match[2]
      owner = User.find_by(username: owner_name)
      return unless owner

      repo = owner.repos.find_by(name: repo_name)
      repo&.update_column(:last_pushed_at, Time.current)
    rescue => e
      Rails.logger.error("Failed to update last_pushed_at: #{e.message}")
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
