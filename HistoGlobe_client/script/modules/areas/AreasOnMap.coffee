window.HG ?= {}

class HG.AreasOnMap

  FOCUS = off

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onFocusArea'
    @addCallback 'onUnfocusArea'
    @addCallback 'onSelectArea'

  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add areasOnMap to HG instance
    @_hgInstance.areasOnMap = @

    # init variables
    @_map = @_hgInstance.map._map

    # event handling
    @_hgInstance.onAllModulesLoaded @, () =>

      # listen to area changes from both area controller and edit mode
      if @_hgInstance.areaController
        controller = @_hgInstance.areaController

        controller.onCreateArea @, (area) =>
          @_addGeometry area
          @_addName area

        controller.onCreateAreaGeometry @, (area) =>
          @_addGeometry area

        controller.onCreateAreaName @, (area) =>
          @_addName area

        controller.onUpdateAreaGeometry @, (area) =>
          @_updateGeometry area

        controller.onUpdateAreaName @, (area) =>
          @_updateName area

        controller.onUpdateAreaStatus @, (area) =>
          @_updateProperties area

        controller.onSelectArea @, (area) =>
          @_updateProperties area
          @_map.fitBounds area.geomLayer.getBounds() if FOCUS

        controller.onDeselectArea @, (area) =>
          @_updateProperties area
          @_map.fitBounds area.geomLayer.getBounds() if FOCUS

        controller.onRemoveArea @, (area) =>
          @_removeName area
          @_removeGeometry area

        controller.onRemoveAreaGeometry @, (area) =>
          @_removeGeometry area

        controller.onRemoveAreaName @, (area) =>
          @_removeName area


      else
        console.error "Unable to show areas on the map: AreaController module not detected in HistoGlobe instance!"


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  ### AREA VISUALIZATION ###

  # ============================================================================
  # add leaflet layers to the map
  # (separation for geometry = MultiPolygon and name = Label)

  # ----------------------------------------------------------------------------
  _addGeometry: (area) ->

    # styling area in CSS based on its calss is a bad idea,
    # because d3 can not update that => use leaflet layer options
    # initial options (including style properties)
    # to have them ready for being changied in d3
    properties = area.getStyle()
    options = {
      'className':    'area'
      'clickable':    true
      'fillColor':    properties.areaColor
      'fillOpacity':  properties.areaOpacity
      'color':        properties.borderColor
      'opacity':      properties.borderOpacity
      'weight':       properties.borderWidth
    }

    area.geomLayer = new L.multiPolygon area.getGeometry().latLng(), options

    # interaction
    area.geomLayer.on 'mouseover', @_onFocus
    area.geomLayer.on 'mouseout', @_onUnfocus
    area.geomLayer.on 'click', @_onClick

    # create double-link: leaflet layer knows HG area and HG area knows leaflet layer
    area.geomLayer.hgArea = area
    area.geomLayer.addTo @_map


  # ----------------------------------------------------------------------------
  _addName: (area) ->

    # create label with name and position
    area.nameLayer = new L.Label()
    # TODO: set back @_addLinebreaks
    area.nameLayer.setContent area.getName()
    area.nameLayer.setLatLng area.getRepresentativePoint()

    # create double-link: leaflet label knows HG area and HG area knows leaflet label
    area.nameLayer.hgArea = area
    @_map.showLabel area.nameLayer

    # put text in center of label
    area.nameLayer.options.offset = [
      -(area.nameLayer._container.offsetWidth/2),
      -(area.nameLayer._container.offsetHeight/2)
    ]
    area.nameLayer._updatePosition()


  # ============================================================================
  # change leaflet layers on the map

  # ----------------------------------------------------------------------------
  _updateGeometry: (area) ->
    area.geomLayer.setLatLngs area.getGeometry().latLng()
    # TODO: necessary?
    area.geomLayer.hgArea = area

  # ----------------------------------------------------------------------------
  _updateName: (area) ->
    area.nameLayer.setContent area.getName()
    area.nameLayer.setLatLng area.getRepresentativePoint()
    # TODO: necessary?
    area.nameLayer.hgArea = area

    # recenter text
    area.nameLayer.options.offset = [
      -(area.nameLayer._container.offsetWidth/2),
      -(area.nameLayer._container.offsetHeight/2)
    ]
    area.nameLayer._updatePosition()

  # ----------------------------------------------------------------------------
  _updateProperties: (area) ->
    properties = area.getStyle()
    @_animate area.geomLayer, {
      'fill':           properties.areaColor
      'fill-opacity':   properties.areaOpacity
      'stroke':         properties.borderColor
      'stroke-opacity': properties.borderOpacity
      'stroke-width':   properties.borderWidth
    }, HGConfig.animation_time.val


  # ============================================================================
  # remove leaflet layers from map

  _removeGeometry: (area) ->
    # remove double-link: leaflet layer from area and area from leaflet layer
    @_map.removeLayer area.geomLayer
    area.geomLayer = null

  # ----------------------------------------------------------------------------
  _removeName: (area) ->
    # remove double-link: leaflet layer from area and area from leaflet layer
    @_map.removeLayer area.nameLayer
    area.nameLayer = null


  ### EVENT HANDLING ###

  # ============================================================================
  _onFocus: (evt) =>
    @notifyAll 'onFocusArea', evt.target.hgArea

  # ----------------------------------------------------------------------------
  _onUnfocus: (evt) =>
    @notifyAll 'onUnfocusArea', evt.target.hgArea

  # ----------------------------------------------------------------------------
  _onClick: (evt) =>
    @notifyAll 'onSelectArea', evt.target.hgArea
    # bug: after clicking, it is assumed to be still focused
    # fix: unfocus afterwards
    @_onUnfocus evt


  ### HELPER FUNCTIONS ###

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
  # actual animation, N.B. needs animation duration as a parameter !!!
  _animate: (area, attributes, duration, finishFunction) ->
    console.error "no animation duration given" if not duration?
    if area._layers?
      for id, path of area._layers
        d3.select(path._path).transition().duration(duration).attr(attributes).each('end', finishFunction)
    else if area._path?
      d3.select(area._path).transition().duration(duration).attr(attributes).each('end', finishFunction)