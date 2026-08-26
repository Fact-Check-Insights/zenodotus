# typed: ignore

class VideoUploader < Shrine
  Attacher.derivatives do |original|
    # A video file can arrive corrupt/incomplete (e.g. missing the MP4 `moov`
    # atom when the upstream scraper mirror truncated it). FFmpeg then fails to
    # read it and would abort the whole archive. Skip the preview in that case
    # and keep archiving the rest of the item.
    begin
      preview = Tempfile.new ["#{SecureRandom.uuid}-preview", ".jpg"]

      video = FFMPEG::Movie.new(original.path)
      video.screenshot(preview.path)

      { preview: preview }
    rescue FFMPEG::Error, StandardError => e
      Rails.logger.warn "[video_uploader] skipping preview for unreadable video: #{e.class}: #{e.message}"
      {}
    end
  end
end
