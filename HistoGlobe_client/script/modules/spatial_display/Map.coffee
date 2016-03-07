window.HG ?= {}

# ==============================================================================
# Class for displaying a 2D Map using leaflet. Derived from Display base class.
# ==============================================================================
class HG.Map extends HG.SpatialDisplay

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    HG.SpatialDisplay.call @

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onClick"

  # ============================================================================
  # Inits associated data.
  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add module to HG instance
    @_hgInstance.map = @

    # call constructor of base class
    super @_hgInstance

    # append pathes
    # @_config.tiles = @_hgInstance.getConfig().configPath + @_config.tiles
    # @_config.tilesHC = @_hgInstance.getConfig().configPath + @_config.tilesHC

    ### INIT MEMBERS ###
    @_map       = null
    @_mapParent = null
    @_isRunning = false

    ### SETUP UI ###
    @_mapParent = document.createElement 'div'
    @_mapParent.style.width = HG.SpatialDisplay.CONTAINER.offsetWidth + "px"
    @_mapParent.style.height = HG.SpatialDisplay.CONTAINER.offsetHeight + "px"
    @_mapParent.style.zIndex = "#{HG.SpatialDisplay.Z_INDEX}"

    HG.SpatialDisplay.CONTAINER.appendChild @_mapParent

    # leaflet
    options =
      maxZoom:      @_hgInstance._config.maxZoom
      minZoom:      @_hgInstance._config.minZoom
      zoomControl:  false
      maxBounds:    @_hgInstance._config.maxBounds
      worldCopyJump: true

    @_map = L.map @_mapParent, options
    @_map.setView @_hgInstance._config.startLatLong, @_hgInstance._config.startZoom
    @_map.attributionControl.setPrefix ''

    tileLayer = L.tileLayer(@_hgInstance._config.tiles + '/{z}/{x}/{y}.png')
    tileLayer.addTo @_map

    @overlayContainer = @_map.getPanes().mapPane

    @_isRunning = true


    ### INTERACTION ###
    # control buttons

    @_hgInstance.onAllModulesLoaded @, () =>
      if @_hgInstance.buttons.zoomIn?
        @_hgInstance.buttons.zoomIn.onClick @, () =>
          @_map.zoomIn()

      if @_hgInstance.buttons.zoomOut?
        @_hgInstance.buttons.zoomOut.onClick @, () =>
          @_map.zoomOut()

      if @_hgInstance.buttons.highContrast?
        @_hgInstance.buttons.highContrast.onEnter @, () =>
          tileLayer.setUrl @_hgInstance._config.tilesHighContrast + '/{z}/{x}/{y}.png'

        @_hgInstance.buttons.highContrast.onLeave @, () =>
          tileLayer.setUrl @_hgInstance._config.tiles + '/{z}/{x}/{y}.png'

    # window
    window.addEventListener 'resize', @_onWindowResize, false
    @_mapParent.addEventListener 'click', @_onClick, false


  # ============================================================================
  # Activates the 2D Display-
  # ============================================================================
  start: ->
    unless @_isRunning
      @_isRunning = true
      @_mapParent.style.display = "block"

  # ============================================================================
  # Deactivates the 2D Display-
  # ============================================================================
  stop: ->
    @_isRunning = false
    @_mapParent.style.display = "none"

  # ============================================================================
  # Returns whether the display is active or not.
  # ============================================================================
  isRunning: ->
    @_isRunning

  # ============================================================================
  # Returns the DOM element associated with the display.
  # ============================================================================
  getCanvas: ->
    @_mapParent

  # ============================================================================
  # Implementation of setting the center of the current display.
  # ============================================================================
  setCenter: (longLat, offset) ->
    # center marker ~ 2/3 vertically and horizontally
    if offset? # if offset passed to function
      # Calculate the offset
      bounds = @_map.getBounds()
      bounds_lat = bounds._northEast.lat - bounds._southWest.lat
      bounds_lng = bounds._northEast.lng - bounds._southWest.lng

      target =
        lon: parseFloat(longLat.x) + offset.x * bounds_lng
        lat: parseFloat(longLat.y) + offset.y * bounds_lat

      @_map.panTo target

    else # no offset? -> center marker
      @_map.panTo
        lon: longLat.x
        lat: longLat.y

  # ============================================================================
  # Implementation of zooming to a specifig area.
  # ============================================================================
  zoomToBounds: (minLong, minLat, maxLong, maxLat) ->
    @_map.fitBounds [
      [minLat, minLong],
      [maxLat, maxLong]
    ]

  # ============================================================================
  # Returns the coordinates of the current center of the display.
  # ============================================================================
  getCenter: () ->
    [@_map.getCenter().long, @_map.getCenter().lat]

  # ============================================================================
  # Resize the display.
  # ============================================================================
  resize: (width, height) ->
    @_mapParent.style.width = width + "px"
    @_mapParent.style.height = height + "px"
    @_map.invalidateSize()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _onWindowResize: (event) =>
    @_mapParent.style.width = $(HG.SpatialDisplay.CONTAINER.parentNode).width() + "px"
    @_mapParent.style.height = $(HG.SpatialDisplay.CONTAINER.parentNode).height() + "px"

  # ============================================================================
  _onClick: (event) =>
    @notifyAll "onClick", event.target