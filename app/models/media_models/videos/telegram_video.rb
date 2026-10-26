# typed: ignore

class MediaModels::Videos::TelegramVideo < ApplicationRecord
  include VideoUploader::Attachment(:video)

  # Optional is marked true here because the image is technically saved before
  # it's added to the model itself.
  belongs_to :telegram_post, optional: true, class_name: "Sources::TelegramPost"
end
