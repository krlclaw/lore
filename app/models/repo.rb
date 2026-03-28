class Repo < ApplicationRecord
  NAME_FORMAT = /\A[a-z][a-z0-9-]*\z/

  belongs_to :owner, class_name: "User"
  has_many :stars, dependent: :destroy

  validates :name,
    presence: true,
    uniqueness: { scope: :owner_id },
    format: { with: NAME_FORMAT, message: "must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens" }
  validates :path, presence: true

  # tags is stored as JSON text
  def tags
    JSON.parse(super || "[]")
  rescue JSON::ParserError
    []
  end

  def tags=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end

  # stars_count is a counter-cached column maintained by Rails.
  # For seed/demo repos, it can be overridden to a higher value.

  # Build the text used for embedding: name + description + tags
  def embedding_input
    parts = [name, description.presence, tags.join(" ")].compact
    parts.join(" — ")
  end

  # Generate and store embedding from OpenAI
  def generate_embedding!
    vector = Lore::EmbeddingService.embed(embedding_input)
    update_column(:embedding, vector.to_json)
    vector
  end

  # Parsed embedding vector
  def embedding_vector
    return nil if embedding.blank?
    JSON.parse(embedding.is_a?(String) ? embedding : embedding.to_json)
  rescue JSON::ParserError
    nil
  end

  def clone_url(request = nil)
    host = request ? "#{request.protocol}#{request.host_with_port}" : ""
    "#{host}/git/#{owner.username}/#{name}.git"
  end

  def web_url(request = nil)
    host = request ? "#{request.protocol}#{request.host_with_port}" : ""
    "#{host}/#{owner.username}/#{name}"
  end

  # Initialize a bare git repo on disk with HEAD pointing to main
  def init_bare_repo!
    FileUtils.mkdir_p(path)
    system("git", "init", "--bare", path, exception: true)
    # Set HEAD to point to refs/heads/main
    File.write(File.join(path, "HEAD"), "ref: refs/heads/main\n")
    # Explicitly deny non-fast-forward pushes
    system("git", "-C", path, "config", "receive.denyNonFastForwards", "true", exception: true)
  end

  def self.create_with_bare_repo!(owner:, name:, description: "", tags: [])
    repo_root = Rails.application.config.lore_repo_root
    disk_path = File.join(repo_root, owner.username, "#{name}.git")

    repo = create!(
      owner: owner,
      name: name,
      description: description,
      tags: tags,
      path: disk_path
    )
    repo.init_bare_repo!
    repo.generate_embedding! rescue Rails.logger.warn("Embedding generation failed for #{repo.name}")
    repo
  end
end
