window.HG ?= {}

class HG.Gallery

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      interactive : true
      showPagination : true

    @_config = $.extend {}, defaultConfig, config

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onSlideChanged"

    @id = ++LAST_GALLERY_ID

    @mainDiv = document.createElement "div"
    @mainDiv.className = "hg-gallery"

    galleryContainer = document.createElement "div"
    galleryContainer.id = "hg-gallery-#{@id}"
    galleryContainer.className = "hg-gallery-slider"

    @_gallery = document.createElement "div"
    @_gallery.className = "swiper-wrapper swiper-no-swiping"

    leftShadow = document.createElement "div"
    leftShadow.className = "shadow shadow-left"

    rightShadow = document.createElement "div"
    rightShadow.className = "shadow shadow-right"

    @mainDiv.appendChild leftShadow
    @mainDiv.appendChild rightShadow

    @mainDiv.appendChild galleryContainer
    galleryContainer.appendChild @_gallery

    if @_config.showPagination
      @_leftnavi = document.createElement "i"
      @_leftnavi.className = "navi navi-left  fa fa-chevron-circle-left"

      @_rightnavi = document.createElement "i"
      @_rightnavi.className = "navi navi-right fa fa-chevron-circle-right"

      pagination = document.createElement "span"
      pagination.id = "hg-gallery-pagination-#{@id}"
      pagination.className = "gallery-pagination"

      paginationContainer = document.createElement "span"
      paginationContainer.className = "pagination-container"
      paginationContainer.appendChild pagination

      @mainDiv.appendChild @_leftnavi
      @mainDiv.appendChild @_rightnavi
      @mainDiv.appendChild paginationContainer


  # ============================================================================
  init: () ->
    pagination_div = undefined

    if @_config.showPagination
      pagination_div = "#hg-gallery-pagination-#{@id}"

    @swiper = new Swiper "#hg-gallery-#{@id}",
      grabCursor: true
      paginationClickable: @_config.showPagination
      pagination: pagination_div
      longSwipesRatio: 0.2
      calculateHeight: true
      preventLinksPropagation: true
      preventLinks: true
      #loop: true
      onSlideChangeEnd: @_onSlideEnd
      onlyExternal: !@_config.interactive

    if @_config.showPagination
      $(@_leftnavi).click () =>
        @swiper.swipePrev()

      $(@_rightnavi).click () =>
        @swiper.swipeNext()

    # for some reason needed...
    # window.setTimeout () =>
    #   @swiper.reInit()
    #   @_updatenavis()
    # , 1000

  # ============================================================================
  reInit: ()->
    @swiper.reInit()
    @swiper.swipeTo(@swiper.activeIndex, 0, false)

  # ============================================================================
  addDivSlide: (div) ->
    slide = document.createElement "div"
    slide.className = "swiper-slide"
    slide.appendChild div

    @_addSlide slide

  # ============================================================================
  addHTMLSlide: (html) ->
    slide = document.createElement "div"
    slide.className = "swiper-slide"
    slide.innerHTML = html

    @_addSlide slide

  # ============================================================================
  getSlideCount: () ->
    @swiper.slides.length

  # ============================================================================
  getActiveSlide: () ->
    @swiper.activeIndex

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _addSlide: (slide) ->
    @_gallery.appendChild slide
    @swiper.reInit()

  # ============================================================================
  _onSlideEnd: () =>
    @_updatenavis()
    @notifyAll "onSlideChanged", @getActiveSlide()

  # ============================================================================
  _updatenavis: () =>
    slide = @getActiveSlide()

    if slide is 0
      $(@_leftnavi).addClass("hidden")
      $(@_rightnavi).removeClass("hidden")
    else if slide is @getSlideCount() - 1
      $(@_rightnavi).addClass("hidden")
      $(@_leftnavi).removeClass("hidden")
    else
      $(@_leftnavi).removeClass("hidden")
      $(@_rightnavi).removeClass("hidden")

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  LAST_GALLERY_ID = 0
