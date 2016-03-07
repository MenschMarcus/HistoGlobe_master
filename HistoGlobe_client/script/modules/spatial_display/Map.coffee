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

    # handle config
    defaultConfig =
      minZoom: 1
      maxZoom: 6
      startZoom: 4
      maxBounds: undefined


    @_config = $.extend {}, defaultConfig, config



  # ============================================================================
  # Inits associated data.
  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add module to HG instance
    @_hgInstance.map = @

    # call constructor of base class
    super @_hgInstance

    ### INIT MEMBERS ###
    @_isRunning = no

    ### SETUP UI ###
    @_mapParent = new HG.Div
    @_mapParent.dom().style.width = HG.SpatialDisplay.CONTAINER.offsetWidth + "px"
    @_mapParent.dom().style.height = HG.SpatialDisplay.CONTAINER.offsetHeight + "px"
    @_mapParent.dom().style.zIndex = "#{HG.SpatialDisplay.Z_INDEX}"

    HG.SpatialDisplay.CONTAINER.appendChild @_mapParent

    # leaflet
    options =
      maxZoom:      @_config.maxZoom
      minZoom:      @_config.minZoom
      zoomControl:  false
      maxBounds:    @_config.maxBounds
      worldCopyJump: true

    @_map = L.map @_mapParent.dom(), options
    @_map.setView @_hgInstance.config.startPoint, @_config.startZoom
    @_map.attributionControl.setPrefix ''

    tileLayer = L.tileLayer(@_hgInstance.config.tiles + '/{z}/{x}/{y}.png')
    tileLayer.addTo @_map

    @overlayContainer = @_map.getPanes().mapPane

    @_isRunning = yes


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
          tileLayer.setUrl @_hgInstance.config.tilesHighContrast + '/{z}/{x}/{y}.png'

        @_hgInstance.buttons.highContrast.onLeave @, () =>
          tileLayer.setUrl @_hgInstance.config.tiles + '/{z}/{x}/{y}.png'

    # window
    window.addEventListener 'resize', @_onWindowResize, false
    @_mapParent.dom().addEventListener 'click', @_onClick, false


  # ============================================================================
  # Activates the 2D Display-
  # ============================================================================
  start: ->
    unless @_isRunning
      @_isRunning = yes
      @_mapParent.dom().style.display = "block"

  # ============================================================================
  # Deactivates the 2D Display-
  # ============================================================================
  stop: ->
    @_isRunning = no
    @_mapParent.dom().style.display = "none"

  # ============================================================================
  # Returns whether the display is active or not.
  # ============================================================================
  isRunning: ->
    @_isRunning

  # ============================================================================
  # Returns the DOM element associated with the display.
  # ============================================================================
  getCanvas: ->
    @_mapParent.dom()

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
    @_mapParent.dom().style.width = width + "px"
    @_mapParent.dom().style.height = height + "px"
    @_map.invalidateSize()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _onWindowResize: (event) =>
    @_mapParent.dom().style.width = $(HG.SpatialDisplay.CONTAINER.parentNode).width() + "px"
    @_mapParent.dom().style.height = $(HG.SpatialDisplay.CONTAINER.parentNode).height() + "px"

  # ============================================================================
  _onClick: (event) =>
    @notifyAll "onClick", event.target