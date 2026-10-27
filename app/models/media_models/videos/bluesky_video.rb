# typed: ignore

class MediaModels::Videos::BlueskyVideo < ApplicationRecord
  include VideoUploader::Attachment(:video)

  # Optional is marked true here because the image is technically saved before
  # it's added to the model itself.
  belongs_to :bluesky_post, optional: true, class_name: "Sources::BlueskyPost"
end
