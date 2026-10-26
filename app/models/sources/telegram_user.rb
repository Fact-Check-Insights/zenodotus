class Sources::TelegramUser < ApplicationRecord
  include ArchivableEntity
  include ImageUploader::Attachment(:profile_image) # adds an `image` virtual attribute
  include PgSearch::Model

  multisearchable against: [:handle, :display_name]

  # The posts that a TelegramUser has authored
  has_many :telegram_posts, foreign_key: :author_id, dependent: :destroy

  # Create a +TelegramUser+ from an Antena author hash
  #
  # @!scope class
  # @params telegram_users [Array[Hash]] an array of authors grabbed from Antena
  # @returns [Array[ArchiveEntity]] an array of +ArchiveEntity+ with type of TelegramUser that have been
  #   saved
  sig { params(telegram_users: T::Array[Hash]).returns(T::Array[ArchiveEntity]) }
  def self.create_from_telegram_hash(telegram_users)
    telegram_users.map do |telegram_user|
      # First check if the user already exists, if so, return that. We key on
      # the handle (like TikTokUser): for channel posts the sender *is* the
      # channel, so the channel's author page collects the channel's posts.
      user = Sources::TelegramUser.find_by(handle: telegram_user["username"])
      telegram_user_hash = self.telegram_user_hash_from_telegram_user(telegram_user)

      # If there's no user, then create it
      if user.nil?
        user = Sources::TelegramUser.create!(telegram_user_hash)
        user = ArchiveEntity.create! archivable_entity: user
      else
        # Update Telegram user with the new data
        #
        # Question: do we want to version this at some point so we can tell what the user had when
        # it was accessed at any given time?
        user.update!(telegram_user_hash)

        # We return the ArchiveEntity, because it's expected
        user = user.archive_entity
      end

      user
    end
  end

  # The unique service id for this item
  #
  # @returns String the handle of this user (the channel username for channel posts)
  sig { returns(String) }
  def service_id
    handle
  end

  # The platform that this author is associated with.
  #
  # @returns String of the platform name
  sig { returns(String) }
  def platform
    "telegram"
  end

private

  # Create a hash from an Antena author suitable for a new TelegramUser or updating one
  #
  # @!scope class
  # @!visibility private
  # @params telegram_user Hash an author grabbed from Antena
  # @returns Hash a data structure suitable to pass to `create` or `update`
  sig { params(telegram_user: Hash).returns(Hash) }
  def self.telegram_user_hash_from_telegram_user(telegram_user)
    profile_image_path = nil
    # If a valid S3 object key is present, download the user's profile image from s3
    if telegram_user["aws_profile_image_key"].present?
      profile_image_path = AwsS3Downloader.download_file_in_s3_received_from_hypatia(telegram_user["aws_profile_image_key"])
    elsif telegram_user["profile_image"].present?
      # We create a temp file and write the image data to it, which yea, is dumb,
      # and there may be a better way to do it, but this works to fix the encoding issues
      # (basically, when we call `create` later, Rails tries to convert the string into UTF-8
      # which obviously breaks everything)
      tempfile = Tempfile.new(binmode: true)
      tempfile.write(Base64.decode64(telegram_user["profile_image"]))
      profile_image_path = tempfile.path
      tempfile.close!
    end

    hash_to_return = {
      telegram_id:        telegram_user["id"],
      handle:             telegram_user["username"],
      display_name:       telegram_user["name"],
      number_of_posts:    telegram_user["number_of_posts"] || telegram_user["posts_count"],
      followers_count:    telegram_user["followers_count"],
      following_count:    telegram_user["following_count"],
      verified:           telegram_user["verified"],
      profile:            telegram_user["profile"],
      url:                telegram_user["profile_link"],
      profile_image_url:  telegram_user["profile_image_url"],
    }
    hash_to_return[:profile_image] = File.open(profile_image_path, binmode: true) if profile_image_path.present?

    hash_to_return
  end
end
