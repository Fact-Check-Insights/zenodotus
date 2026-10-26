class Sources::BlueskyUser < ApplicationRecord
  include ArchivableEntity
  include ImageUploader::Attachment(:profile_image) # adds an `image` virtual attribute
  include PgSearch::Model

  multisearchable against: [:handle, :display_name]

  # The posts that a BlueskyUser has authored
  has_many :bluesky_posts, foreign_key: :author_id, dependent: :destroy

  # Create a +BlueskyUser+ from an Antena author hash
  #
  # @!scope class
  # @params bluesky_users [Array[Hash]] an array of authors grabbed from Antena
  # @returns [Array[ArchiveEntity]] an array of +ArchiveEntity+ with type of BlueskyUser that have been
  #   saved
  sig { params(bluesky_users: T::Array[Hash]).returns(T::Array[ArchiveEntity]) }
  def self.create_from_bluesky_hash(bluesky_users)
    bluesky_users.map do |bluesky_user|
      # First check if the user already exists, if so, return that
      user = Sources::BlueskyUser.find_by(did: bluesky_user["id"])
      bluesky_user_hash = self.bluesky_user_hash_from_bluesky_user(bluesky_user)

      # If there's no user, then create it
      if user.nil?
        user = Sources::BlueskyUser.create!(bluesky_user_hash)
        user = ArchiveEntity.create! archivable_entity: user
      else
        # Update Bluesky user with the new data
        #
        # Question: do we want to version this at some point so we can tell what the user had when
        # it was accessed at any given time?
        user.update!(bluesky_user_hash)

        # We return the ArchiveEntity, because it's expected
        user = user.archive_entity
      end

      user
    end
  end

  # The unique service id for this item
  #
  # @returns String the id assigned by Bluesky to this user
  sig { returns(String) }
  def service_id
    did
  end

  # The platform that this author is associated with.
  #
  # @returns String of the platform name
  sig { returns(String) }
  def platform
    "bluesky"
  end

private

  # Create a hash from an Antena author suitable for a new BlueskyUser or updating one
  #
  # @!scope class
  # @!visibility private
  # @params bluesky_user Hash an author grabbed from Antena
  # @returns Hash a data structure suitable to pass to `create` or `update`
  sig { params(bluesky_user: Hash).returns(Hash) }
  def self.bluesky_user_hash_from_bluesky_user(bluesky_user)
    profile_image_path = nil
    # If a valid S3 object key is present, download the user's profile image from s3
    if bluesky_user["aws_profile_image_key"].present?
      profile_image_path = AwsS3Downloader.download_file_in_s3_received_from_hypatia(bluesky_user["aws_profile_image_key"])
    elsif bluesky_user["profile_image"].present?
      # We create a temp file and write the image data to it, which yea, is dumb,
      # and there may be a better way to do it, but this works to fix the encoding issues
      # (basically, when we call `create` later, Rails tries to convert the string into UTF-8
      # which obviously breaks everything)
      tempfile = Tempfile.new(binmode: true)
      tempfile.write(Base64.decode64(bluesky_user["profile_image"]))
      profile_image_path = tempfile.path
      tempfile.close!
    end

    hash_to_return = {
      did:                bluesky_user["id"],
      handle:             bluesky_user["username"],
      display_name:       bluesky_user["name"],
      number_of_posts:    bluesky_user["number_of_posts"] || bluesky_user["posts_count"],
      followers_count:    bluesky_user["followers_count"],
      following_count:    bluesky_user["following_count"],
      verified:           bluesky_user["verified"],
      profile:            bluesky_user["profile"],
      url:                bluesky_user["profile_link"],
      profile_image_url:  bluesky_user["profile_image_url"],
    }
    hash_to_return[:profile_image] = File.open(profile_image_path, binmode: true) if profile_image_path.present?

    hash_to_return
  end
end
