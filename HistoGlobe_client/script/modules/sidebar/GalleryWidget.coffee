# window.HG ?= {}

# class HG.GalleryWidget extends HG.Widget

#   ##############################################################################
#   #                            PUBLIC INTERFACE                                #
#   ##############################################################################

#   # ============================================================================
#   constructor: (config) ->
#     defaultConfig =
#       icon: ""
#       name: ""
#       interactive : true
#       showPagination : true

#     @_config = $.extend {}, defaultConfig, config

#     HG.mixin @, HG.CallbackContainer
#     HG.CallbackContainer.call @

#     @addCallback "onSlideChanged"

#     HG.Widget.call @, @_config

#   # ============================================================================
#   hgInit: (hgInstance) ->
#     super hgInstance

#     @_gallery = new HG.Gallery @_config

#     @_gallery.onSlideChanged @, (slide) =>
#       @notifyAll "onSlideChanged", slide

#     @mainDiv = document.createElement "div"
#     @mainDiv.className = "gallery-widget"
#     @mainDiv.appendChild @_gallery.mainDiv

#     @setName    @_config.name
#     @setIcon    @_config.icon
#     @setContent @mainDiv

#     @_gallery.init()

#   # ============================================================================
#   addDivSlide: (div, clickCallback=undefined) ->
#     @_gallery.addDivSlide div, clickCallback

#   # ============================================================================
#   addHTMLSlide: (html, clickCallback=undefined) ->
#     @_gallery.addHTMLSlide html, clickCallback

#   # ============================================================================
#   getSlideCount: () ->
#     @_gallery.getSlideCount()

#   # ============================================================================
#   getActiveSlide: () ->
#     @_gallery.getActiveSlide()

window.HG ?= {}

class HG.GalleryWidget extends HG.Widget

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      icon: ""
      name: ""

    @_config = $.extend {}, defaultConfig, config

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onSlideChanged"

    @_id = ++LAST_GALLERY_ID

    HG.Widget.call @, @_config

  # ============================================================================
  hgInit: (hgInstance) ->
    super hgInstance

    @_galleryContent = document.createElement "div"
    @_galleryContent.className = "gallery-widget"

    galleryContainer = document.createElement "div"
    galleryContainer.id = "gallery-widget-#{@_id}"
    galleryContainer.className = "gallery-widget-slider"
    galleryContainer.style.width = "#{@_config.width}px"

    @_gallery = document.createElement "div"
    @_gallery.className = "swiper-wrapper swiper-no-swiping"

    @_leftArrow = document.createElement "i"
    @_leftArrow.className = "arrow arrow-left  fa fa-chevron-circle-left"

    leftShadow = document.createElement "div"
    leftShadow.className = "shadow shadow-left"

    @_rightArrow = document.createElement "i"
    @_rightArrow.className = "arrow arrow-right fa fa-chevron-circle-right"

    rightShadow = document.createElement "div"
    rightShadow.className = "shadow shadow-right"

    pagination = document.createElement "span"
    pagination.id = "gallery-widget-pagination-#{@_id}"
    pagination.className = "gallery-pagination"

    paginationContainer = document.createElement "span"
    paginationContainer.className = "pagination-container"
    paginationContainer.appendChild pagination

    @_galleryContent.appendChild leftShadow
    @_galleryContent.appendChild rightShadow
    @_galleryContent.appendChild @_leftArrow
    @_galleryContent.appendChild @_rightArrow
    @_galleryContent.appendChild galleryContainer
    @_galleryContent.appendChild paginationContainer
    galleryContainer.appendChild @_gallery

    @setName @_config.name
    @setIcon @_config.icon
    @setContent @_galleryContent

    @_swiper = new Swiper "#gallery-widget-#{@_id}",
      grabCursor: true
      paginationClickable: true
      pagination: "#gallery-widget-pagination-#{@_id}"
      longSwipesRatio: 0.2
      calculateHeight: true
      onSlideChangeEnd: @_onSlideEnd


    $(@_leftArrow).click () =>
      @_swiper.swipePrev()

    $(@_rightArrow).click () =>
      @_swiper.swipeNext()

    # for some reason needed...
    window.setTimeout () =>
      @_swiper.reInit()
      @_updateArrows()
    , 1000

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
    @_swiper.slides.length

  # ============================================================================
  getActiveSlide: () ->
    @_swiper.activeIndex

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _addSlide: (slide) ->
    @_gallery.appendChild slide
    @_swiper.reInit()

  # ============================================================================
  _onSlideEnd: () =>
    @_updateArrows()
    @notifyAll "onSlideChanged", @getActiveSlide()

  # ============================================================================
  _updateArrows: () =>
    slide = @getActiveSlide()

    if slide is 0
      $(@_leftArrow).addClass("hidden")
      $(@_rightArrow).removeClass("hidden")
    else if slide is @getSlideCount() - 1
      $(@_rightArrow).addClass("hidden")
      $(@_leftArrow).removeClass("hidden")
    else
      $(@_leftArrow).removeClass("hidden")
      $(@_rightArrow).removeClass("hidden")

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  LAST_GALLERY_ID = 0



