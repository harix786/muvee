class VideosController < ApplicationController
  before_action :set_video, only: [:show, :edit, :update, :destroy, :stream, :left_off_at, :thumbnails]

  respond_to :json, only: [:left_off_at, :thumbnails]

  def index
    @movies = Movie.local.all
    @series = Series.all
    @items = @movies.to_a.concat @series.to_a
    @items.sort_by!{|item| -item.created_at.to_i} # newest first
  end

  def list
    @videos = Video.all
  end

  # GET /videos/1
  # GET /videos/1.json
  def show
    if @video.is_tv?
      if @video.series.present?
        @video.series.last_watched_video_id = @video.id
        @video.series.save
      end

      if params[:shuffle].present?
        @next_episode = TvShow.all.sample
      elsif @video.series.present?
        episodic = @video.series.tv_shows.release_order
        index_of_current_episode = episodic.to_a.find_index{|vid| vid.id == @video.id}
        @previous_episode = episodic.at(index_of_current_episode - 1) if index_of_current_episode > 0
        @next_episode = episodic.at(index_of_current_episode + 1) if index_of_current_episode < (episodic.length - 1)
      end
    end
    render layout: 'fullscreen'
  end

  def shuffle
    random_show = TvShow.all.sample
    redirect_to video_path(random_show, shuffle: true)
  end

  # GET /videos/new
  def new
    @video = Video.new
  end

  # GET /videos/1/edit
  def edit
  end

  def generate
    # TODO: make this service create from a user-defined endpoint
    service = VideoCreationService.new({
      tv: ['/media/anthony/Slowsto/TV'],
      movies: ['/media/anthony/Slowsto/Movies']
    })

    @new_tv_shows, @failed_tv_shows, @new_movies, @failed_movies = service.generate()

    respond_to do |format|
      format.json { render json: {
        new_tv_shows: @new_tv_shows,
        failed_tv_shows: @failed_tv_shows,
        new_movies: @new_movies,
        failed_movies: @failed_movies
      }, status: :ok}
    end
  end

  # GET /videos/1/stream
  def stream
    video_extension = File.extname(@video.raw_file_path)[1..-1]

    send_file @video.raw_file_path,
      filename: File.basename(@video.raw_file_path),
      type: Mime::Type.lookup_by_extension(video_extension),
      type: 'video/mp4',
      disposition: 'inline',
      stream: true,
      buffer_size: 4096
  end

  # POST /videos/reanalyze
  def reanalyze
    if existing_jobs.include? "AnalyzerWorker"
      already_working
    else
      AnalyzerWorker.perform_async({method: :reanalyze})
      render json: {status: "ok"}
    end
  end

  def redownload
    if existing_jobs.include? "AnalyzerWorker"
      already_working
    else
      AnalyzerWorker.perform_async({method: :redownload})
      render json: {status: "ok"}
    end
  end

  def redownload_missing
    if existing_jobs.include? "AnalyzerWorker"
      already_working
    else
      AnalyzerWorker.perform_async({method: :redownload_missing})
      render json: {status: "ok"}
    end
  end

  # POST /videos/1/left_off_at.json
  def left_off_at
    @video.update_attribute(:left_off_at, params[:left_off_at])
    render json: {status: "ok"}
  end

  # GET /videos/1/thumbnails.json
  def thumbnails
    # builds thumbnails if they don't exist, returns them if they do
    # all videos start with 1 thumbnail
    if @video.thumbnails.count != 10
      @video.thumbnails.destroy_all
      @video.create_n_thumbnails(10)
    end

    render json: {thumbnails: @video.thumbnails.map{|t| t.url}}
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_video
      @video = Video.find(params[:id])
    end

    def already_working
      render json: {status: "Please wait; this task is already running."}, status: 409
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def video_params
      params.require(:video).permit(:raw_file_path, :type, :episode, :season, :duration, :left_off_at, :series_id)
    end

    def existing_jobs
      jobs = [Sidekiq::ScheduledSet.new.to_a, Sidekiq::RetrySet.new.to_a, Sidekiq::Queue.new("analyze").to_a, Sidekiq::Queue.new("transcode").to_a]
      jobs = jobs.inject([]) {|set, el| set.concat el}
      existing_jobs = jobs.map do |job|
        job.display_class
      end
    end
end
