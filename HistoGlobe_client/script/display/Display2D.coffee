window.HG ?= {}

# ==============================================================================
# Class for displaying a 2D Map using leaflet. Derived from Display base class.
# ==============================================================================
class HG.Display2D extends HG.Display

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->
    HG.Display.call @

  # ============================================================================
  # Inits associated data.
  # ============================================================================
  hgInit: (hgInstance) ->
    super hgInstance

    @_hgInstance = hgInstance

    # @_labelController = labelController
    @_initMembers()
    @_initCanvas()
    @_initEventHandling()
    # @_initLabels()

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
  _initMembers: ->
    @_map       = null
    @_mapParent = null
    @_isRunning = false

  # ============================================================================
  # Sets up leaflet
  # ============================================================================
  _initCanvas: ->
    @_mapParent = document.createElement "div"
    @_mapParent.style.width = HG.Display.CONTAINER.offsetWidth + "px"
    @_mapParent.style.height = HG.Display.CONTAINER.offsetHeight + "px"
    @_mapParent.style.zIndex = "#{HG.Display.Z_INDEX}"

    HG.Display.CONTAINER.appendChild @_mapParent

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

    @_hgInstance.onAllModulesLoaded @, () =>
      if @_hgInstance.zoom_buttons?
        @_hgInstance.zoom_buttons.onZoomIn @, () =>
          @_map.zoomIn()

        @_hgInstance.zoom_buttons.onZoomOut @, () =>
          @_map.zoomOut()

      if @_hgInstance.highcontrast_button?
        @_hgInstance.highcontrast_button.onEnterHighContrast @, () =>
          tileLayer.setUrl @_hgInstance._config.tilesHighContrast + '/{z}/{x}/{y}.png'

        @_hgInstance.highcontrast_button.onLeaveHighContrast @, () =>
          tileLayer.setUrl @_hgInstance._config.tiles + '/{z}/{x}/{y}.png'

    @overlayContainer = @_map.getPanes().mapPane
    @_isRunning = true

  # ============================================================================
  _initEventHandling: ->
    window.addEventListener 'resize', @_onWindowResize, false

  # ============================================================================
  _initLabels: ->

    @_visibleLabels = []

    @_labelController.onShowLabel @, (label) =>
      @_showLabel label

    @_labelController.onHideLabel @, (label) =>
      @_hideLabel label

  # ============================================================================
  _onWindowResize: (event) =>
    @_mapParent.style.width = $(HG.Display.CONTAINER.parentNode).width() + "px"
    @_mapParent.style.height = $(HG.Display.CONTAINER.parentNode).height() + "px"


  # ============================================================================
  _showLabel: (label) =>
    label.myLeafletLabel = new L.Label();
    label.myLeafletLabel.setContent label.getName()
    label.myLeafletLabel.setLatLng label.getLatLng()
    @_map.showLabel label.myLeafletLabel
    label.myLeafletLabel.options.offset = [
      -label.myLeafletLabel._container.offsetWidth/2,
      -label.myLeafletLabel._container.offsetHeight/2
    ]

    label.myLeafletLabel._updatePosition()
    $(label.myLeafletLabel._container).addClass("visible")


  # ============================================================================
  _hideLabel: (label) =>
    $(label.myLeafletLabel._container).removeClass("visible")
    @_visibleLabels.splice(@_visibleLabels.indexOf(label), 1)
    @_map.removeLayer label.myLeafletLabel
