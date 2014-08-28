require 'test_helper'

class TvShowTest < ActiveSupport::TestCase
  def setup
    Series.any_instance.stubs(download_images: true)
  end

  test 'can create' do
    TvShow.any_instance.stubs(:associate_with_series)
    TvShow.any_instance.stubs(:extract_metadata)
    show = TvShow.create(raw_file_path: "/foo/bar")
    assert_equal "TvShow", show.type
  end

  test '#filename_no_extension strips out the filename correctly' do
    TvShow.any_instance.stubs(:associate_with_series)
    TvShow.any_instance.stubs(:extract_metadata)
    show = TvShow.create(raw_file_path: "/foo/bar/filename.jpg")
    assert_equal "filename", show.filename_no_extension
  end

  test 'guesses something when no format matches' do
    TvShow.any_instance.stubs(:associate_with_series)
    TvShow.any_instance.stubs(:extract_metadata)
    show = TvShow.create(raw_file_path: '/foo/bar/Maggie.Simpson.in.The.Longest.Daycare.HDTV.x264-2HD.mp4')
    assert_equal "Maggie Simpson In The Longest Daycare 2 Hd", show.title

    show = TvShow.create(raw_file_path: '/foo/bar/AdventureTimeWithFinnAndJake.HDTV.x264-2HD.mp4')
    assert_equal "Adventure Time With Finn And Jake 2 Hd", show.title
  end

  test 'guesses standard format correctly on create' do
    TvShow.any_instance.stubs(:associate_with_series)
    TvShow.any_instance.stubs(:extract_metadata)
    examples = [
      "/foo/bar/Show.Name.S01E02.Source.Quality.Etc-Group.mp4",
      "/foo/bar/Show Name - S01E02 - My Ep Name.mp4",
      "/foo/bar/Show.Name.S01.E02.My.Ep.Name.mp4",
      "/foo/bar/Show.Name.S01E02E03.Source.Quality.Etc-Group.mp4",
      "/foo/bar/Show Name - S01E02-03 - My Ep Name.mp4",
      "/foo/bar/Show.Name.S01.E02.E03.mp4"
    ]

    examples.each do |name|
      show = TvShow.create(raw_file_path: name)
      assert_equal "Show Name", show.title, "Testing: #{name}"
      assert_equal 1, show.season, "Testing: #{name}"
      assert_equal 2, show.episode, "Testing: #{name}"
    end
  end

  test 'guesses fov format correctly on create' do
    TvShow.any_instance.stubs(:associate_with_series)
    TvShow.any_instance.stubs(:extract_metadata)
    show = TvShow.create(raw_file_path: "/foo/bar/Rick and Morty - 1x11 - Ricksy Business.webm")

    assert_equal "Rick And Morty", show.title
    assert_equal 1, show.season
    assert_equal 11, show.episode

    show = TvShow.create(raw_file_path: "/foo/bar/Rick and Morty - 1.11 - Ricksy_Business.webm")
    assert_equal "Rick And Morty", show.title
    assert_equal 1, show.season
    assert_equal 11, show.episode
  end

  test 'will create a new series if one does not exist' do
    VCR.use_cassette 'family_guy' do
      assert_difference 'Series.all.length', 1 do
        TvShow.create(raw_file_path: '/foo/bar/Family.Guy.S11E21.HDTV.x264-LOL.mp4')
      end
    end
  end

  test 'will not create duplicate new series' do
    VCR.use_cassette 'family_guy' do
      assert_difference 'Series.all.length', 1 do
        TvShow.create(raw_file_path: '/foo/bar/Family.Guy.S11E21.HDTV.x264-LOL.mp4')
        TvShow.create(raw_file_path: '/foo/bar/Family.Guy.S11E22.HDTV.x264-LOL.mp4')
        TvShow.create(raw_file_path: '/foo/bar/Family.Guy.S11E23.HDTV.x264-LOL.mp4')
      end
    end
  end

  test 'will potentially change the name of the tvshow to match the remote datasource recommendation' do
    VCR.use_cassette 'american_dad' do
      show = TvShow.create(raw_file_path: '/foo/bar/American.Dad.S11E21.HDTV.x264-LOL.mp4')
      show.reload
      assert_equal "American Dad!", show.title
      assert_equal "American Dad!", Series.last.title
      assert Series.last.tvdb_id
      assert Series.last.tvdb_series_result
    end
  end

  test 'can get to episodic metadata' do
    VCR.use_cassette 'american_dad' do
      show = TvShow.create(raw_file_path: '/foo/bar/American.Dad.S05E10.HDTV.x264-LOL.mp4')
      show.reload
      assert_equal "Family Affair", show.episode_specific_metadata[:EpisodeName]
      assert_equal "When the Smiths try to plan a family game night, Roger is full of excuses about prior commitments. However, when he is caught in a lie, the Smiths feel stabbed in the back when they realize Roger has been cheating on them with other families. Stan, Francine, Hayley and Steve go on the offensive to teach Roger a lesson about monogamy until Roger has a breakthrough about why he isn't a one family kind-of-guy.", show.episode_specific_metadata[:Overview]
    end
  end
end
