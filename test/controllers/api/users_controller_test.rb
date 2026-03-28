require "test_helper"

class Api::UsersControllerTest < ActionDispatch::IntegrationTest
  test "POST /api/users creates user and returns PAT" do
    post "/api/users", params: { username: "newuser-#{SecureRandom.hex(4)}" }, as: :json
    assert_response :created
    body = JSON.parse(response.body)
    assert body["user"]["username"]
    assert body["pat"].start_with?("lore_pat_")
  end

  test "POST /api/users rejects duplicate username" do
    name = "dupuser-#{SecureRandom.hex(4)}"
    post "/api/users", params: { username: name }, as: :json
    assert_response :created
    post "/api/users", params: { username: name }, as: :json
    assert_response :conflict
  end

  test "GET /api/users/:username/repos lists repos" do
    user = User.create_with_pat(username: "lister-#{SecureRandom.hex(4)}")
    Repo.create_with_bare_repo!(owner: user, name: "repo-a", description: "A")

    get "/api/users/#{user.username}/repos", as: :json
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body["repos"].length
    assert_equal "repo-a", body["repos"][0]["name"]
  end

  test "GET /api/users/:username/repos returns 404 for unknown user" do
    get "/api/users/nonexistent/repos", as: :json
    assert_response :not_found
  end
end
