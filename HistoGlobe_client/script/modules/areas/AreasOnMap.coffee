window.HG ?= {}

class HG.AreasOnMap

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  NUM_LABEL_PRIOS = 5

  # ============================================================================
  constructor: (config) ->
    @_map             = null
    @_areaController  = null

  # ============================================================================
  hgInit: (@_hgInstance) ->

    @_hgInstance.areasOnMap = @
    @_map = @_hgInstance.map._map
    @_areaController = @_hgInstance.areaController

    @_zoomLevel = @_map.getZoom()

    # event handling
    if @_areaController

      # change of areas
      @_areaController.onAddArea @, (area) =>
        @_addArea area
        @_addLabel area

    else
      console.error "Unable to show areas on Map: AreaController module not detected in HistoGlobe instance!"


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  # AREAS
  # ============================================================================

  # ============================================================================
  # physically adds area to the map, but makes it invisible
  _addArea: (area) ->
    if not area.myLeafletLayer?

      # take style of country but make it invisible
      options = {
          "clickable":    true,
          "color":        "#000",
          "opacity":      0.3,
          "fillColor":    "#fff",
          "fillOpacity":  0.2
          "weight":       1.0,
      };

      # create layer with loaded geometry and style
      area.myLeafletLayer = L.multiPolygon area.getGeometry(), options

      # interaction
      area.myLeafletLayer.on "mouseover", @_onHover     # TODO: why does hover not work?
      area.myLeafletLayer.on "mouseout", @_onUnHover
      area.myLeafletLayer.on "click", @_onClick

      # create double-link: leaflet layer knows HG area and HG area knows leaflet layer
      area.myLeafletLayer.hgArea = area
      area.myLeafletLayer.addTo @_map

  # ============================================================================
  _addLabel: (label) ->
    if not label.myLeafletLabel?
      # create invisible label with name and position
      label.myLeafletLabel = new L.Label()
      label.myLeafletLabel.setContent @_addLinebreaks label.getLabelName()
      label.myLeafletLabel.setLatLng label.getLabelPos()
      # add label to map
      @_map.showLabel label.myLeafletLabel
      label.myLeafletLabelIsVisible = true

      # put in center of label
      label.myLeafletLabel.options.offset = [
        -label.myLeafletLabel._container.offsetWidth/2,
        -label.myLeafletLabel._container.offsetHeight/2
      ]
      label.myLeafletLabel._updatePosition()


  # ============================================================================
  # HELPER
  # ============================================================================

  # ============================================================================
  _onHover: (event) =>
    @_animate event.target, {
      "fill": "#0f0"
    } , 150

  # ============================================================================
  _onUnHover: (event) =>
    @_animate event.target, {
      "fill": "#fff"
    }, 150

  # ============================================================================
  _onClick: (event) =>
    console.log event.target.hgArea
    @_map.fitBounds event.target.getBounds()

  # ============================================================================
  _addLinebreaks : (name) =>
    # 1st approach: break at all whitespaces and dashed lines
    name = name.replace /\s/gi, '<br\>'
    name = name.replace /\-/gi, '-<br\>'

    # # find all whitespaces in the name
    # len = name.length
    # regEx = /\s/gi  # finds all whitespaces (\s) globally (g) and case-insensitive (i)
    # posWhite = []
    # while result = regEx.exec name
    #   posWhite.push result.index
    # for posW in posWhite

    name

  # ============================================================================
  _animate: (area, attributes, duration, finishFunction) ->
    if area._layers?
      for id, path of area._layers
        d3.select(path._path).transition().duration(duration).attr(attributes).each("end", finishFunction)
    else if area._path?
      d3.select(area._path).transition().duration(duration).attr(attributes).each("end", finishFunction)

