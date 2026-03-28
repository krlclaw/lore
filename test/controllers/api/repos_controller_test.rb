require "test_helper"

class Api::ReposControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create_with_pat(username: "repoctl-#{SecureRandom.hex(4)}")
    @pat = @user.plaintext_pat
  end

  test "POST /api/repos creates repo with bare git repo" do
    post "/api/repos",
      params: { name: "new-tool", description: "A new tool", tags: ["test"] },
      headers: { "Authorization" => "Bearer #{@pat}" },
      as: :json
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "new-tool", body["repo"]["name"]
    assert_equal @user.username, body["repo"]["owner"]
    assert body["repo"]["clone_url"].end_with?("/git/#{@user.username}/new-tool.git")
    assert_nil body["repo"]["last_pushed_at"]
  end

  test "POST /api/repos requires authentication" do
    post "/api/repos", params: { name: "no-auth" }, as: :json
    assert_response :unauthorized
  end

  test "POST /api/repos rejects duplicate name" do
    post "/api/repos",
      params: { name: "dup-repo" },
      headers: { "Authorization" => "Bearer #{@pat}" },
      as: :json
    assert_response :created

    post "/api/repos",
      params: { name: "dup-repo" },
      headers: { "Authorization" => "Bearer #{@pat}" },
      as: :json
    assert_response :conflict
  end

  test "GET /api/repos/:owner/:name returns repo details" do
    Repo.create_with_bare_repo!(owner: @user, name: "show-me", description: "Visible")

    get "/api/repos/#{@user.username}/show-me", as: :json
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "show-me", body["repo"]["name"]
    assert_equal "Visible", body["repo"]["description"]
    assert_equal "main", body["repo"]["default_branch"]
  end

  test "GET /api/repos/:owner/:name returns 404 for missing repo" do
    get "/api/repos/#{@user.username}/nonexistent", as: :json
    assert_response :not_found
  end
end
