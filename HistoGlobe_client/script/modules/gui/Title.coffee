window.HG ?= {}

class HG.Title

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      contentClass: ""
      contentConfig: []

    @_config = $.extend {}, defaultConfig, config

  # ============================================================================
  hgInit: (hgInstance) ->

    @hgInstance = hgInstance

    @_div               = document.createElement("div")
    @_div.className     = "hg-title"

    $("#histoglobe").append @_div

    if @_config.contentClass isnt "" and window["HG"][@_config.contentClass]?
      content = new window["HG"][@_config.contentClass] @_config.contentConfig
      @setContent content
    else
      console.error "Failed to initialize Title module: The content class " +
                     "#{@_config.contentClass} does not exist!"

    $(window).on 'resize', @_resize
    @_resize()

  # ============================================================================
  setContent: (content) ->
    content.init @hgInstance, @_div

  # ============================================================================
  _resize: () =>
    height = $(@_div).outerHeight()
    @hgInstance._top_area.style.top = height + "px"
    @hgInstance._onResize()

