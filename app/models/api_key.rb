# typed: strict

class ApiKey < ApplicationRecord
  KEY_PREFIX_LENGTH = T.let(8, Integer)

  belongs_to :user, required: true
  attr_reader :api_key

  validates :description, presence: true

  scope :active, -> { where(active: true) }

  before_create :create_api_key

  sig { void }
  def create_api_key
    @api_key = SecureRandom.alphanumeric(30)
    self.hashed_api_key = ZenoEncryption.hash_string(@api_key)
    # Only the hash is stored, the prefix lets admins tell keys apart in the dashboard
    self.key_prefix = @api_key.first(KEY_PREFIX_LENGTH)
  end

  def update_with_use(request)
    self.update({ last_used: Time.now })
  end
end
