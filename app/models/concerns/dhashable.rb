# typed: false

module Dhashable
  extend ActiveSupport::Concern
  extend T::Sig

  included do
    before_save :generate_single_dhash
    before_save :generate_dhashes_for_uploaded_media
    after_save :generate_dhashes_for_attached_media
  end

  # Returns whether the object is a image attachment type or a video attachment type
  #
  # @return a symbol telling which type of attachment this is
  sig { returns(Symbol) }
  def attachment_type
    return :video if self.archivable_item.respond_to?("videos") && !self.videos.empty?
    return :image if self.archivable_item.respond_to?("images") && !self.images.empty?

    raise "Unable to determine type of attachment. You shouldn't be seeing this."
  end

  def generate_dhashes_for_attached_media
    return unless self.respond_to?(:archivable_item)
    return if self.videos.empty? && self.images.empty?
    return if attachment_type == :video # TODO: move video dhashing to a background job — blocks Sidekiq threads for hours on long videos

    self.archivable_item.images.each do |media_item|
      begin
        media_item.image.open
      rescue Shrine::FileNotFound
        next
      end

      tempfile_path = media_item.image.tempfile.path
      dhash = Eikon.dhash_for_image(tempfile_path)
      ImageHash.create!({ dhash: dhash, archive_item: self })
      media_item.image.close
    end
  end

  def generate_dhashes_for_uploaded_media
    return unless self.respond_to?(:dhashes)
    return if self.video.nil? && self.image.nil?
    return if self.image.nil? # TODO: move video dhashing to a background job

    self.image.open
    tempfile_path = self.image.tempfile.path
    self.dhashes = [Eikon.dhash_for_image(tempfile_path)]
  end

  def generate_single_dhash
    return unless self.respond_to?(:dhash)

    self.image.open
    tempfile_path = self.image.tempfile.path
    self.dhash = Eikon.dhash_for_image(tempfile_path)
  end
end
