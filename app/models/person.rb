class Person < ActiveRecord::Base
  has_many :people_video
  has_many :movies, -> { where(videos: {type: 'Movie'}) }, through: :people_video, source: :video
  has_many :tv_shows, -> { where(videos: {type: 'TvShow'}) }, through: :people_video, source: :video
  has_many :persons_series
  has_many :series, through: :persons_series

  has_many :images
  has_many :profile_images

  has_many :roles

  validates :full_name, presence: true, uniqueness: {case_sensitive: false}

  def reanalyze
    TmdbPersonMetadataService.new(tmdb_id).run
  end

  def default_profile_picture
    return nil unless profile_images.present?
    profile_images.sample.url
  end

  def videos_and_series
    self.roles.map do |role|
      role.series || role.video
    end
  end
end