require 'test_helper'

class MovieTest < ActiveSupport::TestCase
  test "will attempt to grab duration & create initial thumbnail & extract metadata on create" do
    Movie.any_instance.expects(:associate_with_genres).once
    Movie.any_instance.expects(:guessit).once
    Movie.any_instance.expects(:create_initial_thumb).once
    Movie.any_instance.expects(:shellout_and_grab_duration).once
    Movie.any_instance.expects(:extract_metadata).once
    Movie.any_instance.expects(:download_poster).once
    Movie.any_instance.expects(:examine_thumbnail_for_3d).once
    Movie.create(raw_file_path: "/foo/bar/Truer.Grit.mp4")
  end

  test "can download posters" do
    VCR.use_cassette "download_posters_test" do
      movie = videos(:true_grit)
      movie.download_poster
      assert movie.reload.poster_path.present?
    end
  end

  test "#query_tmdb_fanart returns an array of URLs" do
    VCR.use_cassette "query_tmdb_fanart" do
      movie = videos(:true_grit)
      assert_equal Array, movie.query_tmdb_fanart.class
      assert_equal 13, movie.query_tmdb_fanart.length
    end
  end

  test "#query_tmdb_fanart returns empty array if we don't know IMDB ID" do
    movie = videos(:true_grit)
    movie.stubs(:fetch_imdb_id).returns(nil)
    assert_equal Array, movie.query_tmdb_fanart.class
    assert_equal 0, movie.query_tmdb_fanart.length
  end

  test "#query_fanart_tv_fanart returns an array of URLs" do
    VCR.use_cassette "query_fanart_tv_fanart" do
      movie = videos(:true_grit)
      assert_equal Array, movie.query_fanart_tv_fanart.class
      assert_equal 1, movie.query_fanart_tv_fanart.length
    end
  end

  test "#query_fanart_tv_fanart returns empty array if we don't know IMDB ID" do
    movie = videos(:true_grit)
    movie.stubs(:fetch_imdb_id).returns(nil)
    assert_equal Array, movie.query_fanart_tv_fanart.class
    assert_equal 0, movie.query_fanart_tv_fanart.length
  end

  test "#download_fanart will create fanart resources (that attempt to download)" do
    Fanart.any_instance.stubs(:download_image_file).returns(true)
    VCR.use_cassette "download_fanart" do
      movie = videos(:true_grit)
      assert_difference "movie.fanarts.length", 14 do
        movie.download_fanart
      end
    end
  end

  test "#is_movie?" do
    movie = videos(:true_grit)
    assert movie.is_movie?
    show = videos(:american_dad_s01_e01)
    refute show.is_movie?
  end

  test "reanalyze calls Video::reanalyze" do
    Video.any_instance.expects(:reanalyze).once
    Movie.any_instance.expects(:guessit).once
    Movie.any_instance.expects(:associate_with_genres).once
    Movie.any_instance.expects(:extract_metadata).once
    Movie.any_instance.expects(:redownload_missing).once

    movie = videos(:true_grit)
    movie.reanalyze
  end

  test "reanalyze sets the status of a video to local" do # sketchy, may not be want is wanted
    Movie.any_instance.expects(:guessit).once
    Movie.any_instance.expects(:associate_with_genres).once
    Movie.any_instance.expects(:extract_metadata).once
    Movie.any_instance.expects(:redownload_missing).once

    movie = videos(:true_grit)
    movie.update_attribute(:status, "remote")
    movie.reanalyze
    assert movie.local?
  end

  test "reanalyze does not guessit if imdb id is accurate" do
    Movie.any_instance.expects(:guessit).never
    Movie.any_instance.expects(:associate_with_genres).once
    Movie.any_instance.expects(:extract_metadata).once
    Movie.any_instance.expects(:redownload_missing).once

    movie = videos(:true_grit)
    movie.update_attribute(:imdb_id_is_accurate, true)
    movie.reanalyze
  end

  test "reanalyze performs a few subtasks" do
    Movie.any_instance.expects(:guessit).once
    Movie.any_instance.expects(:associate_with_genres).once
    Movie.any_instance.expects(:extract_metadata).once
    Movie.any_instance.expects(:redownload_missing).once

    movie = videos(:true_grit)
    movie.reanalyze
  end

  test "reanalyze will attempt to redownload fanarts/videos/etc if the imdb_id changes" do
    Movie.any_instance.expects(:guessit).once
    Movie.any_instance.expects(:associate_with_genres).once
    Movie.any_instance.expects(:redownload).once
    Movie.any_instance.expects(:extract_metadata).once
    Movie.any_instance.expects(:redownload_missing).once
    Movie.any_instance.stubs(:imdb_id).returns('a', 'b') # changes during duration of test

    movie = videos(:true_grit)
    movie.imdb_id = "wat"
    movie.reanalyze
  end

  test "extract_metadata works" do
    VCR.use_cassette "extract_metadata_test" do
      movie = videos(:true_grit)
      movie.extract_metadata
      assert_equal "True Grit", movie.title
      assert_equal Time.parse("22 Dec 2010"), movie.released_on
      assert movie.overview.present?
      assert_equal "en", movie.language
      assert_equal "United States of America", movie.country
    end
  end

  test "associate_with_genres works" do
    VCR.use_cassette "extract_metadata_test" do
      movie = videos(:true_grit)
      assert_difference "Genre.count", 1 do
        movie.associate_with_genres
      end
      assert_no_difference "Genre.count" do
        movie.associate_with_genres
      end

      assert_equal 1, movie.genres.length
    end
  end

  test "#guessit will call Guesser if there's path, and assigns year and title" do
    Guesser::Movie.stubs(:guess_from_filepath).returns(
      year: 1900,
      title: 'True Grit',
      quality: '1080p'
    )

    movie = Movie.new(status: 'local')
    movie.raw_file_path = 'something'
    movie.guessit
    assert_equal "True Grit", movie.title
    assert_equal 1900, movie.year
    assert_equal '1080p', movie.quality
  end

  test "#guessit will set title to unknown if the movie is not local" do
    Guesser::Movie.expects(:guess_from_filepath).never
    movie = Movie.new(status: 'remote')
    movie.guessit
    assert_equal 'Unknown', movie.title
  end
end
