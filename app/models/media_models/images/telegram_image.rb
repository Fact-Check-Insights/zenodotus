# typed: false

class MediaModels::Images::TelegramImage < ApplicationRecord
  include ImageUploader::Attachment(:image)

  # Optional is marked true here because the image is technically saved before
  # it's added to the model itself.
  belongs_to :telegram_post, optional: true, class_name: "Sources::TelegramPost"

  # Returns the parent object of this item. All the MediaModels implement this.
  #
  # @return the parent post of this object
  sig { returns(Sources::TelegramPost) }
  def parent_post
    self.telegram_post
  end
end
