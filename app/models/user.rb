class User < ApplicationRecord
  USERNAME_FORMAT = /\A[a-z][a-z0-9-]*\z/

  has_many :repos, foreign_key: :owner_id, dependent: :destroy
  has_many :stars, dependent: :destroy
  has_many :starred_repos, through: :stars, source: :repo

  validates :username,
    presence: true,
    uniqueness: true,
    format: { with: USERNAME_FORMAT, message: "must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens" }

  # PAT generation — returns the plaintext token (shown once at creation)
  # Stores only the BCrypt digest in pat_digest.
  attr_accessor :plaintext_pat

  def self.create_with_pat(username:)
    user = new(username: username)
    token = generate_pat
    user.plaintext_pat = token
    user.pat_digest = BCrypt::Password.create(token)
    user.save!
    user
  end

  def authenticate_pat(token)
    BCrypt::Password.new(pat_digest).is_password?(token)
  rescue BCrypt::Errors::InvalidHash
    false
  end

  private_class_method def self.generate_pat
    "lore_pat_#{SecureRandom.hex(24)}"
  end
end
