# typed: false

class MediaModels::Images::BlueskyImage < ApplicationRecord
  include ImageUploader::Attachment(:image)

  # Optional is marked true here because the image is technically saved before
  # it's added to the model itself.
  belongs_to :bluesky_post, optional: true, class_name: "Sources::BlueskyPost"

  # Returns the parent object of this item. All the MediaModels implement this.
  #
  # @return the parent post of this object
  sig { returns(Sources::BlueskyPost) }
  def parent_post
    self.bluesky_post
  end
end
