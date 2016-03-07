window.HG ?= {}

# ==============================================================================
# This is HistoGlobe's central class. It initiates module loading and can be
# used to store/gather information on the current state of the application.
# ==============================================================================
class HG.HistoGlobe

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # Class constructor
  # A module configuration file located at "pathToJson" is parsed and evaluated,
  # i.e., all specified modules are constructed and initialized.
  # ============================================================================
  constructor: (pathToJson) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # Callback specification
    # Any object may listen for notifictations on any of the below signals.
    @addCallback "onTopAreaSlide"
    @addCallback "onAllModulesLoaded"
    @addCallback "onMapAreaSizeChange"
    @addCallback "onMapAreaSizeChangeEnd"

    @map = null

    @_config = null

    defaultConfig =
      container: "histoglobe"
      nowYear: 2014
      minYear: 1940
      maxYear: 2020
      minZoom: 1
      maxZoom: 6
      startZoom: 4
      maxBounds: undefined
      startLatLong: [51.505, 10.09]
      tiles: '../HistoGlobe_client/config/common/tiles/tiles'
      tilesHighContrast: '../HistoGlobe_client/config/common/tiles/tiles_high_contrast'
      graphicsPath: '../HistoGlobe_client/config/common/graphics/'

    # issue: HGConfig provides rose variables, but for colors it does not return
    # the hex code '#rrggbb', but an object with r, g, b, a and val attributes
    # the val attribute is a rather weird number string
    # solution: for colors, rewrite this number string to the actual hex value
    for prop, val of HGConfig
      # decide if color value or not
      if val.r? and val.g? and val.b?
        # calculate color value in hex
        r = @_toHex val.r
        g = @_toHex val.g
        b = @_toHex val.b
        # rewrite properties
        val.type = 'color'
        val.val = '#'+r+g+b

    # Asynchronous loading of a file containing module information located at
    # "pathToJson". Result is stored in the "config" object and passed to the
    # specified callback function.
    $.getJSON(pathToJson, (config) =>

      # Config of the central HistoGlobe instance is loaded. $.extend is used to
      # combine the default and the actual config. Thus, all attributes
      # specified in "defaultConfig" are stored in "@_config" and either being
      # overridden by the loaded config or kept as default.
      hgConf = config["HistoGlobe"]
      @_config = $.extend {}, defaultConfig, hgConf
      @_config.container = document.getElementById @_config.container

      # GUI creation
      @_createTopArea()

      @_createMap()

      $(window).on 'resize', @_onResize

      # Auxiliary function for module loading. Tries to create an object by the
      # name of "moduleName", passing "moduleConfig" to the object's constructor.
      # If the creation was successful, "hgInit" is called on the new module.
      load_module = (moduleName, moduleConfig) =>

        # error handling: ignore comment modules:
        # "### COMMENT ###"
        return if moduleName.startsWith('#') and moduleName.endsWith('#')

        defaultConf =
          enabled : true

        moduleConfig = $.extend {}, defaultConf, moduleConfig

        # Check if there exists a module by the specified name. To ensure custom
        # modules they must be added them to the HG scope
        # usage: class HG.ModuleName
        if window["HG"][moduleName]?
          # Only load modules which are enabled
          if moduleConfig.enabled
            newMod = new window["HG"][moduleName] moduleConfig
            @addModule newMod
        else
          console.error "The module #{moduleName} is not part of the HG namespace!"

      # Load all modules specified in the configuration file.
      for moduleName, moduleConfig of config
        '''if moduleName is "Widgets"
          for widget in moduleConfig
            load_module widget.type, widget
        else if moduleName isnt "HistoGlobe"'''
        if moduleName isnt "HistoGlobe"
          load_module moduleName, moduleConfig

        window.hgConf=config

      # After all modules are loaded, notify whoever is interested
      @notifyAll "onAllModulesLoaded"

      @_updateLayout()
    )


  # ============================================================================
  # Calls "hgInit" on the object "module". A reference to the HistoGlobe
  # instance. Thus, modules may interact with and/or save a reference to the
  # HistoGlobe instance within hgInit.
  # ============================================================================
  addModule: (module) ->
    module.hgInit @

  # ============================================================================
  # Checks whether or not the application is running in mobile mode.
  # ============================================================================
  isInMobileMode: =>
    window.innerWidth < HGConfig.map_min_width.val

  # ============================================================================
  # Returns the effective size of the map area.
  # ============================================================================
  getMapAreaSize: () ->
    return size =
      x: window.innerWidth
      y: $(@_top_area).outerHeight()

  # ============================================================================
  # Returns the DOM element containing all HistoGLobe visuals
  # ============================================================================
  getContainer: () ->
    @_config.container

  # ============================================================================
  # Getter for information on time boundaries/the visualization's start year.
  # ============================================================================
  getMinMaxYear: () ->
    [@_config.minYear, @_config.maxYear]

  getStartYear: () ->
    @_config.nowYear

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _createTopArea: ->
    @_top_area = @_createElement @_config.container, "div", "top-area"
    @_top_area_wrapper = @_createElement @_top_area, "div", ""
    @_top_area_wrapper.className = "swiper-wrapper"

    @_top_swiper = new Swiper '#top-area',
      mode:'horizontal'
      slidesPerView: 'auto'
      noSwiping: true
      longSwipesRatio: 0.1
      moveStartThreshold: 10
      # onSlideReset: @_onSlideEnd
      onSetWrapperTransform: (s, t) => @_onSlide(t)
      onSetWrapperTransition: (s, d) =>
        if d is 0
          $(@mapCanvas).addClass("no-animation")
        else
          $(@mapCanvas).removeClass("no-animation")


  # ============================================================================
  # Creates 2D Map. For more information, please see Display2D.coffe.
  # ============================================================================

  _createMap: ->
    @_map_area = @_createElement @_top_area_wrapper, "div", "map-area"
    @_map_area.className = "swiper-slide"

    @mapCanvas = @_createElement @_map_area, "div", "map-canvas"
    @mapCanvas.className = "swiper-no-swiping"

    @_map_area.appendChild @mapCanvas
    @map = new HG.Display2D
    @addModule @map

  # ============================================================================
  _onResize: () =>
    @_updateLayout()

  # ============================================================================
  _updateLayout: =>
    width = window.innerWidth
    height = window.innerHeight - $(@_top_area).offset().top

    map_height = height - HGConfig.timeline_height.val
    map_width = width

    @_map_area.style.width = "#{map_width}px"
    @_map_area.style.height = "#{map_height}px"

    @map.resize map_width, map_height

    @_top_swiper.reInit()

  # ============================================================================
  _createElement: (container, type, id) ->
    div = document.createElement type
    div.id = id
    container.appendChild div
    return div

  # ============================================================================
  _toHex: (prop) ->
    v = prop.toString 16
    v = "0"+v if v.length is 1
    v