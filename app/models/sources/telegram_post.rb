class Sources::TelegramPost < ApplicationRecord
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

  has_many :images, foreign_key: :telegram_post_id, class_name: "MediaModels::Images::TelegramImage", dependent: :destroy
  accepts_nested_attributes_for :images, allow_destroy: true

  has_many :videos, foreign_key: :telegram_post_id, class_name: "MediaModels::Videos::TelegramVideo", dependent: :destroy
  accepts_nested_attributes_for :videos, allow_destroy: true

  # The `TelegramUser` that is the author of this post.
  belongs_to :author, class_name: "TelegramUser"

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
    TelegramMediaSource.send(:validate_telegram_post_url, url)
  rescue TelegramMediaSource::InvalidTelegramPostUrlError
    false
  end

  # Create an +ArchiveItem+ from a +url+ as a string
  #
  # @!scope class
  # @params url String a string of a url
  # @params user The user adding the ArchiveItem
  # returns ArchiveItem with type TelegramPost that has been saved to the database
  sig { params(url: String, user: T.nilable(User), initiated_from: Integer).returns(ArchiveItem) }
  def self.create_from_url!(url, user = nil, initiated_from: nil)
    raise "You have to start from somewhere.... (No inititated_from submitted)" if initiated_from.nil?

    telegram_response = TelegramMediaSource.extract(url, MediaSource::ScrapeType::Telegram, true, initiated_from: initiated_from)["scrape_result"]
    raise "Error sending job to the scraper" unless telegram_response.respond_to?(:first) && telegram_response.first.has_key?("id")
    Sources::TelegramPost.create_from_telegram_hash(telegram_response, user).first
  end

  # Returns the scrape type for the +Scrapable+ concernt
  #
  # @!scope class
  # @returns [MediaSource::ScrapeType] the type of scrape that this class is
  sig { returns(MediaSource::ScrapeType) }
  def self.scrape_type
    MediaSource::ScrapeType::Telegram
  end

  # An alias for create_from_telegram_hash painted with a generic name so it can be called in a model agnostic fashion
  # @params telegram_posts [Array[Hash]] an array of Telegram posts grabbed from the scraper
  # @returns [Array[ArchiveItem]] an array of ArchiveItem with type TelegramPost that have been
  #   saved to the graph database
  sig { params(telegram_posts: T::Array[Hash], user: T.nilable(User)).returns(T::Array[ArchiveItem]) }
  def self.create_from_hash(telegram_posts, user = nil)
    create_from_telegram_hash(telegram_posts, user)
  end

  # Create an +ArchiveItem+ from a scraper response
  #
  # @!scope class
  # @params telegram_posts [Array[Hash]] an array of Telegram posts grabbed from the scraper
  # @params user User the current user creating an ArchiveItem
  # @returns [Array[ArchiveItem]] an array of ArchiveItem with type TelegramPost that have been
  #   saved to the graph database
  sig { params(telegram_posts: T::Array[Hash], user: T.nilable(User)).returns(T::Array[ArchiveItem]) }
  def self.create_from_telegram_hash(telegram_posts, user = nil)
    telegram_posts.map do |telegram_post|
      telegram_post_data = telegram_post["post"]
      author_json = telegram_post_data["author"] || {}
      # For channel posts the sender *is* the channel; when the scraper reports
      # no author, fall back to the channel parsed out of a public permalink so
      # the post still lands on a meaningful author page. (Private t.me/c/ links
      # carry no channel name, so they are skipped.)
      if author_json["username"].blank? && telegram_post_data["url"].present? &&
          telegram_post_data["url"] !~ %r{t\.me/c/}i
        channel = telegram_post_data["url"][%r{t\.me/(?:s/)?([A-Za-z0-9_]{4,32})/}i, 1]
        author_json = author_json.merge("username" => channel) if channel.present?
      end
      telegram_user = Sources::TelegramUser.create_from_telegram_hash([author_json]).first.telegram_user

      image_attributes = []
      video_attributes = []
      screenshot_attributes = {}

      if telegram_post_data["aws_screenshot_key"].present?
        downloaded_path = AwsS3Downloader.download_file_in_s3_received_from_hypatia(telegram_post_data["aws_screenshot_key"])
        screenshot_attributes = { image: File.open(downloaded_path, binmode: true) }
      elsif telegram_post_data["screenshot_file"].present?
        # Backwards compatibility for if the scraper sends over the screenshot in Base64.
        # (The in-process Telegram scrape has no browser, so this is normally absent.)
        tempfile = Tempfile.new(binmode: true)
        tempfile.write(Base64.decode64(telegram_post_data["screenshot_file"]))
        screenshot_attributes = { image: File.open(tempfile.path, binmode: true) }
        tempfile.close!
      end

      if telegram_post_data["aws_image_keys"].present?
        image_attributes = telegram_post_data["aws_image_keys"].map do |key|
          downloaded_path = AwsS3Downloader.download_file_in_s3_received_from_hypatia(key)
          { image: File.open(downloaded_path, binmode: true) }
        end
      elsif telegram_post_data["image_files"].present?
        # Backwards compatibility for if the scraper sends over files in Base64
        image_attributes = telegram_post_data["image_files"].map do |image_file_data|
          tempfile = Tempfile.new(binmode: true)
          tempfile.write(Base64.decode64(image_file_data))
          image_attribute = { image: File.open(tempfile.path, binmode: true) }
          tempfile.close!
          image_attribute
        end
      end

      if telegram_post_data["aws_video_keys"].present?
        video_attributes = telegram_post_data["aws_video_keys"].map do |key|
          downloaded_path = AwsS3Downloader.download_file_in_s3_received_from_hypatia(key)
          { video: File.open(downloaded_path, binmode: true) }
        end
      elsif telegram_post_data["video_files"].present?
        video_attributes = telegram_post_data["video_files"].map do |video_file_data|
          tempfile = Tempfile.new(binmode: true)
          tempfile.write(Base64.decode64(video_file_data))
          video_attribute = { video: File.open(tempfile.path, binmode: true) }
          tempfile.close!
          video_attribute
        end
      end

      hash = {
        text:                telegram_post_data["text"],
        telegram_id:         telegram_post["id"],
        language:            (telegram_post_data["language"].presence || "und"),
        posted_at:           telegram_post_data["created_at"],
        url:                 telegram_post_data["url"],
        author:              telegram_user,
        images_attributes:   image_attributes,
        videos_attributes:   video_attributes
      }

      ArchiveItem.create!(archivable_item: Sources::TelegramPost.create!(hash), submitter: user,
                          screenshot_attributes: screenshot_attributes)
    end
  end

  # Get the `service_id` of the Telegram post, in this case the message id
  #
  # @returns String of the ID.
  sig { returns(String) }
  def service_id
    telegram_id
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
      publishing_platform_shortname:    "telegram",
      publishing_platform_display_name: "Telegram",
      author_canonical_path:            url_helpers.media_vault_author_path(self.author, platform: :telegram),
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
