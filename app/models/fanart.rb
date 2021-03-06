class Fanart < ActiveRecord::Base
  include DownloadFile

  belongs_to :video
  belongs_to :actor
  before_create :download_image_file
  before_destroy :destroy_image_file

  SUB_FOLDER = 'fanart'

  def output_folder
    Rails.root.join('public', self.class::SUB_FOLDER)
  end

  attr_writer :remote_location

  def url
    "/#{self.class::SUB_FOLDER}/#{File.basename(raw_file_path)}"
  end

  private

  def download_image_file
    return if @remote_location.blank?
    output_filename = UUID.generate(:compact) + File.extname(@remote_location)
    output_path = output_folder.join(output_filename)
    if download_file(@remote_location, output_path)
      self.raw_file_path = output_path.to_s
    else
      false
    end
  end

  def fanart_path
    output_folder.join(self.raw_file_path)
  end

  def destroy_image_file
    begin
      File.delete(fanart_path)
    rescue => e
      Rails.logger.info "Fanart#destroy_image_file: #{e}"
    end
  end
end
