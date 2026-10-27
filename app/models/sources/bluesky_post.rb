class Sources::BlueskyPost < ApplicationRecord
  include ArchivableItem
  include PgSearch::Model
  include Scrapable

  multisearchable(
    against: :text,
    additional_attributes: -> (post) { {
      private: post.archive_item.nil? ? false : post.archive_item.private, # Messy but meh
      user_id: post.archive_item&.users&.map(&:id)
    } }
  )

  has_many :images, foreign_key: :bluesky_post_id, class_name: "MediaModels::Images::BlueskyImage", dependent: :destroy
  accepts_nested_attributes_for :images, allow_destroy: true

  has_many :videos, foreign_key: :bluesky_post_id, class_name: "MediaModels::Videos::BlueskyVideo", dependent: :destroy
  accepts_nested_attributes_for :videos, allow_destroy: true

  # The `BlueskyUser` that is the author of this post.
  belongs_to :author, class_name: "BlueskyUser"

  after_commit on: [:create] do
    # We only want to create the derivatives once (since you know, it's a media archive we don't
    # want them to change)
    self.videos.each { |video| video.video_derivatives! }
  end


  # Returns a +boolean+ on whether this class can handle the URL passed in.
  # All items that are scraped should implement this class
  #
  # @!scope class
  # @params url String a url for an object to check
  # @return a Boolean on whether or not the class can handle the URL
  sig { params(url: String).returns(T::Boolean) }
  def self.can_handle_url?(url)
    BlueskyMediaSource.send(:validate_bluesky_post_url, url)
  rescue BlueskyMediaSource::InvalidBlueskyPostUrlError
    false
  end

  # Create an +ArchiveItem+ from a +url+ as a string
  #
  # @!scope class
  # @params url String a string of a url
  # @params user The user adding the ArchiveItem
  # returns ArchiveItem with type BlueskyPost that has been saved to the database
  sig { params(url: String, user: T.nilable(User), initiated_from: Integer).returns(ArchiveItem) }
  def self.create_from_url!(url, user = nil, initiated_from: nil)
    raise "You have to start from somewhere.... (No inititated_from submitted)" if initiated_from.nil?

    bluesky_response = BlueskyMediaSource.extract(url, MediaSource::ScrapeType::Bluesky, true, initiated_from: initiated_from)["scrape_result"]
    raise "Error sending job to the scraper" unless bluesky_response.respond_to?(:first) && bluesky_response.first.has_key?("id")
    Sources::BlueskyPost.create_from_bluesky_hash(bluesky_response, user).first
  end

  # Returns the scrape type for the +Scrapable+ concernt
  #
  # @!scope class
  # @returns [MediaSource::ScrapeType] the type of scrape that this class is
  sig { returns(MediaSource::ScrapeType) }
  def self.scrape_type
    MediaSource::ScrapeType::Bluesky
  end

  # An alias for create_from_bluesky_hash painted with a generic name so it can be called in a model agnostic fashion
  # @params bluesky_posts [Array[Hash]] an array of Bluesky posts grabbed from the scraper
  # @returns [Array[ArchiveItem]] an array of ArchiveItem with type BlueskyPost that have been
  #   saved to the graph database
  sig { params(bluesky_posts: T::Array[Hash], user: T.nilable(User)).returns(T::Array[ArchiveItem]) }
  def self.create_from_hash(bluesky_posts, user = nil)
    create_from_bluesky_hash(bluesky_posts, user)
  end

  # Create an +ArchiveItem+ from a scraper response
  #
  # @!scope class
  # @params bluesky_posts [Array[Hash]] an array of Bluesky posts grabbed from the scraper
  # @params user User the current user creating an ArchiveItem
  # @returns [Array[ArchiveItem]] an array of ArchiveItem with type BlueskyPost that have been
  #   saved to the graph database
  sig { params(bluesky_posts: T::Array[Hash], user: T.nilable(User)).returns(T::Array[ArchiveItem]) }
  def self.create_from_bluesky_hash(bluesky_posts, user = nil)
    bluesky_posts.map do |bluesky_post|
      bluesky_post_data = bluesky_post["post"]
      bluesky_user = Sources::BlueskyUser.create_from_bluesky_hash([bluesky_post_data["author"]]).first.bluesky_user

      image_attributes = []
      video_attributes = []
      screenshot_attributes = {}

      if bluesky_post_data["aws_screenshot_key"].present?
        downloaded_path = AwsS3Downloader.download_file_in_s3_received_from_hypatia(bluesky_post_data["aws_screenshot_key"])
        screenshot_attributes = { image: File.open(downloaded_path, binmode: true) }
      elsif bluesky_post_data["screenshot_file"].present?
        # Backwards compatibility for if the scraper sends over the screenshot in Base64.
        # (The API-based Bluesky scraper has no browser, so this is normally absent.)
        tempfile = Tempfile.new(binmode: true)
        tempfile.write(Base64.decode64(bluesky_post_data["screenshot_file"]))
        screenshot_attributes = { image: File.open(tempfile.path, binmode: true) }
        tempfile.close!
      end

      if bluesky_post_data["aws_image_keys"].present?
        image_attributes = bluesky_post_data["aws_image_keys"].map do |key|
          downloaded_path = AwsS3Downloader.download_file_in_s3_received_from_hypatia(key)
          { image: File.open(downloaded_path, binmode: true) }
        end
      elsif bluesky_post_data["image_files"].present?
        # Backwards compatibility for if the scraper sends over files in Base64
        image_attributes = bluesky_post_data["image_files"].map do |image_file_data|
          tempfile = Tempfile.new(binmode: true)
          tempfile.write(Base64.decode64(image_file_data))
          image_attribute = { image: File.open(tempfile.path, binmode: true) }
          tempfile.close!
          image_attribute
        end
      end

      if bluesky_post_data["aws_video_keys"].present?
        video_attributes = bluesky_post_data["aws_video_keys"].map do |key|
          downloaded_path = AwsS3Downloader.download_file_in_s3_received_from_hypatia(key)
          { video: File.open(downloaded_path, binmode: true) }
        end
      elsif bluesky_post_data["video_files"].present?
        video_attributes = bluesky_post_data["video_files"].map do |video_file_data|
          tempfile = Tempfile.new(binmode: true)
          tempfile.write(Base64.decode64(video_file_data))
          video_attribute = { video: File.open(tempfile.path, binmode: true) }
          tempfile.close!
          video_attribute
        end
      end

      hash = {
        text:                bluesky_post_data["text"],
        bluesky_id:          bluesky_post["id"],
        language:            (bluesky_post_data["language"].presence || "und"),
        posted_at:           bluesky_post_data["created_at"],
        number_of_likes:     bluesky_post_data["number_of_likes"],
        number_of_reposts:   bluesky_post_data["number_of_reposts"],
        number_of_replies:   bluesky_post_data["number_of_replies"],
        number_of_quotes:    bluesky_post_data["number_of_quotes"],
        url:                 bluesky_post_data["url"],
        author:              bluesky_user,
        images_attributes:   image_attributes,
        videos_attributes:   video_attributes
      }

      ArchiveItem.create!(archivable_item: Sources::BlueskyPost.create!(hash), submitter: user,
                          screenshot_attributes: screenshot_attributes)
    end
  end

  # Get the `service_id` of the Bluesky post, in this case the AT-URI
  #
  # @returns String of the ID.
  sig { returns(String) }
  def service_id
    bluesky_id
  end

  # Returns the permalink of the post as stored at scrape time
  #
  # @returns a string of the url
  sig { returns(T.nilable(String)) }
  def url
    self[:url]
  end

  # Normalized representation of this archivable item for use in the view template.
  #
  # @returns Hash of normalized attributes.
  sig { returns(Hash) }
  def normalized_attrs_for_views
    {
      publishing_platform_shortname:    "bluesky",
      publishing_platform_display_name: "Bluesky",
      author_canonical_path:            url_helpers.media_vault_author_path(self.author, platform: :bluesky),
      author_profile_image_url:         self.author.profile_image_url,
      author_display_name:              self.author.display_name,
      author_username:                  self.author.handle,
      author_community_count:           self.author.followers_count,
      author_community_noun:            "follower",
      archive_item_self:                self,
      archive_item_caption:             self.text,
      published_at:                     self.posted_at,
    }
  end
end
