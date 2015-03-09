class Muvee.Pager

  constructor: ->
    @currentPage = 0
    $(window).on "scroll.pager", _.debounce(@scrollLoad.bind(this))

    $(document).one 'page:load', @destructor.bind(this)


  destructor: ->
    console.log 'Muvee.Pager::destructor'
    $(window).off "scroll.pager"

  scrollLoad: ->
    console.log 'scroll'
    @loadNextPage() if ($(window).scrollTop() + $(window).height()) >= ($(document).height() - 200)

  loadNextPage: ->
    return if @locked
    @locked = true

    nextPage = @currentPage + 1

    uri = URI().setQuery("page", nextPage)
    
    $.ajax
      url: uri.toString()
    .done (response) =>
      $response = $(response)
      $moreTiles = $response.find(".tile-list").children()

      @currentPage = nextPage

      $(".tile-list").append($moreTiles)
    .always =>
      @locked = false
