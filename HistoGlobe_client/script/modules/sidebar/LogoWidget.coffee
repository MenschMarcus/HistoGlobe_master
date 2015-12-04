window.HG ?= {}

class HG.LogoWidget extends HG.TimeGalleryWidget

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      logos : []

    @_config = $.extend {}, defaultConfig, config

    HG.TimeGalleryWidget.call @, @_config

  # ============================================================================
  hgInit: (hgInstance) ->
    super hgInstance

    for person in @_config.logos
      @addLogo person

    @updatePagination()

  # ============================================================================
  addLogo: (config) ->
    defaultConfig =
      text: ""
      date: ""
      logo: ""

    config = $.extend {}, defaultConfig, config

    div = document.createElement "div"
    div.className = "logo-widget"

    logo = document.createElement "div"
    logo.className = "logo-widget-image"
    logo.style.backgroundImage = "url('#{config.logo}')"
    div.appendChild logo

    name = document.createElement "div"
    name.className = "text"
    name.innerHTML = config.text
    div.appendChild name

    text = document.createElement "div"
    text.className = "clear"
    div.appendChild text

    @addDivSlide {date: config.date, div: div}
