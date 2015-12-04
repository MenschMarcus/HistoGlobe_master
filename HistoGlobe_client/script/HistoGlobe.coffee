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
    @sidebar = null

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
      sidebarCollapsed: "auto"
      sidebarEnabled: "true"
      tiles: 'data/tiles/'

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
      @_config.container =  document.getElementById @_config.container

      # GUI creation
      @_createTopArea()

      @_createMap()

      if @_config.sidebarEnabled
        @_createSidebar()
        @_createCollapseButton()

      $(window).on 'resize', @_onResize

      @_collapsed = true

      # Auxiliary function for module loading. Tries to create an object by the
      # name of "moduleName", passing "moduleConfig" to the object's constructor.
      # If the creation was successful, "hgInit" is called on the new module.
      load_module = (moduleName, moduleConfig) =>
        defaultConf =
          enabled : true

        moduleConfig = $.extend {}, defaultConf, moduleConfig

        # Check if there exists a module by the specified name. To ensure custom
        # modules are found one must add them to the HG scope
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

      # hack: initial call of timeline now change
      # if @timeline?
      #   @timeline._updateNowDate true

      @_updateLayout()

      if @_config.sidebarCollapsed is "false"
        @_collapse()
      else if @_config.sidebarCollapsed is "auto" and @isInMobileMode()
        @_collapse()

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
    window.innerWidth < HGConfig.sidebar_width.val + HGConfig.map_min_width.val

  # ============================================================================
  # Returns the effective size of the map area.
  # ============================================================================
  getMapAreaSize: () ->
    if @_collapsed
      return size =
        x: window.innerWidth - HGConfig.sidebar_collapsed_width.val
        y: $(@_top_area).outerHeight()
    else
      return size =
        x: window.innerWidth - HGConfig.sidebar_width.val
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

    if @_config.sidebarEnabled
      @_top_swiper.wrapperTransitionEnd(@_onSlideEnd, true)

  # ============================================================================
  _createSidebar: ->
    @_sidebar_area = @_createElement @_top_area_wrapper, "div", "sidebar-area"
    @_sidebar_area.className = "swiper-slide"

    @sidebar = new HG.Sidebar
    @addModule @sidebar


  # ============================================================================
  _createCollapseButton: ->
    @_collapse_area_left = @_createElement @_map_area, "div", "collapse-area-left"

    @_collapse_button = @_createElement @_map_area, "i", "collapse-button"
    @_collapse_button.className = "fa fa-arrow-circle-o-left fa-2x"

    $(@_collapse_button).tooltip {title: "Seitenleiste öffnen/schließen", placement: "left", container:"body"}

    $(@_collapse_button).click @_collapse
    $(@_collapse_area_left).click @_collapse

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
  stringToDate: (string) ->
    res = (string + "").split(".")
    i = res.length
    d = new Date(1900, 0, 1)
    if i > 0
        d.setFullYear(res[i - 1])
    else
        alert "Error: were not able to convert string to date."
    if i > 1
        d.setMonth(res[i - 2] - 1)
    if i > 2
        d.setDate(res[i - 3])
    d

  # ============================================================================
  _collapse: =>
    @_collapsed = not @_collapsed

    if @_collapsed
      @_top_swiper.swipePrev()
    else
      @_top_swiper.swipeNext()

  # ============================================================================
  _onSlideEnd: () =>
    if @_last_slide_pos != @_top_swiper.slides[0].getOffset().left
      @_last_slide_pos = @_top_swiper.slides[0].getOffset().left

      @_collapsed = @_last_slide_pos >= 0

      if @_collapsed
        @_collapse_button.className = "fa fa-arrow-circle-o-left fa-2x"
        @_collapse_area_left.style.width = "0px"
      else
        @_collapse_button.className = "fa fa-arrow-circle-o-right fa-2x"
        if @isInMobileMode()
          @_collapse_area_left.style.width = "#{HGConfig.map_collapsed_width.val}px"

      @notifyAll "onMapAreaSizeChangeEnd", window.innerWidth - HGConfig.sidebar_collapsed_width.val + @_last_slide_pos

  # ============================================================================
  _onSlide: (transform) =>
    if (transform.x < 0)
      @mapCanvas.style.right = "#{transform.x/2}px"
    else
      @mapCanvas.style.right = 0

    @notifyAll "onTopAreaSlide", transform.x
    @notifyAll "onMapAreaSizeChange", window.innerWidth - HGConfig.sidebar_collapsed_width.val + transform.x


  # ============================================================================
  _onResize: () =>
    @_updateLayout()

  # ============================================================================
  _updateLayout: =>
    width = window.innerWidth
    height = window.innerHeight - $(@_top_area).offset().top

    map_height = height - HGConfig.timeline_height.val
    map_width = width - if @_config.sidebarEnabled then HGConfig.sidebar_collapsed_width.val else 0
    sidebar_width = HGConfig.sidebar_width.val

    if @isInMobileMode()
      sidebar_width = width - HGConfig.map_collapsed_width.val

    @_map_area.style.width = "#{map_width}px"
    @_map_area.style.height = "#{map_height}px"

    if @_config.sidebarEnabled
      @sidebar.resize sidebar_width, map_height
    @map.resize map_width, map_height

    @_top_swiper.reInit()

    unless @_collapsed
      @_top_swiper.swipeNext()

  # ============================================================================
  _createElement: (container, type, id) ->
    div = document.createElement type
    div.id = id
    container.appendChild div
    return div
