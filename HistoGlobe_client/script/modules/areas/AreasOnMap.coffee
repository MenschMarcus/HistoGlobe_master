window.HG ?= {}

class HG.AreasOnMap

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  NUM_LABEL_PRIOS = 5
  ANIMATION_DURATION = 150

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onActivateArea'
    @addCallback 'onDeactivateArea'
    @addCallback 'onSelectArea'
    @addCallback 'onDeselectArea'

    # init variables
    @_multipleSelections = no
    @_activeTarget  = null        # for single-seletion mode: save active area itself
    @_activeAreas   = 0           # for multiple-selection mode: save number of selected areas

  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add areasOnMap to HG instance
    @_hgInstance.areasOnMap = @

    # init variables
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

  # ============================================================================
  # handle multiple selections mode (and state number of possible selections)
  enableMultipleSelection: (num) ->  # can receive a number (1, 2, 3, ... , MAX_NUM)
    @_multipleSelections = num
    @_activeAreas = 0

  disableMultipleSelection: () ->
    @_multipleSelections = no
    @_activeAreas = 0
    @_deactivateAll()

  # ============================================================================
  getActiveArea: () -> @_activeTarget?.hgArea

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  # physically adds area to the map, but makes it invisible
  _addArea: (area) ->
    if not area.myLeafletLayer?

      # create area as leaflet layer -> clickable and class name to style it in css
      # setting class to area and style it with css is a bad idea,
      # because d3 can not update that => use leaflet layer options
      # NB! different vocabulary for leaflet layers and svg paths (animated by d3)
      #   property          leaflet       svg
      #   area color        fillColor     fill
      #   area opacity      fillOpacity   fill-opactiy
      #   border color      color         stroke
      #   border opacity    opacity       stroke-opacity
      #   border width      weight        stroke-width

      options = {
        'className':    'area'
        'clickable':    true
        'fillColor':    HGConfig.color_white.val
        'fillOpacity':  HGConfig.area_opacity.val
        'color':        HGConfig.color_bg_dark.val
        'opacity':      HGConfig.border_opacity.val
        'weight':       HGConfig.border_width.val
      }
      area.myLeafletLayer = L.multiPolygon area.getGeometry(), options

      # interaction
      area.myLeafletLayer.on 'mouseover', @_onHover
      area.myLeafletLayer.on 'mouseout', @_onUnHover
      area.myLeafletLayer.on 'click', @_onClick

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


  ### EVENTS ###

  # ============================================================================
  _onHover: (event) =>
    if not event.target.hgArea.isActive()
      @_animate event.target, {
        'fill': HGConfig.color_highlight.val
      }, ANIMATION_DURATION

  # ============================================================================
  _onUnHover: (event) =>
    if not event.target.hgArea.isActive()
      @_animate event.target, {
        'fill': HGConfig.color_white.val
      }, ANIMATION_DURATION

  # ============================================================================
  _onClick: (event) =>
    target = event.target
    area = target.hgArea

    # single-selection mode
    if not @_multipleSelections
      # clicking inactive area => activate it and deactivate currently active area
      if not area.isActive()
        @_deactivate @_activeTarget
        @_activate target
        @notifyAll 'onActivateArea', area

      # clicking active area => deactivate it
      else
        @_deactivate @_activeTarget
        @notifyAll 'onDeactivateArea', area


    # multiple-selection mode
    else
      # clicking inactive area => activate it
      if not area.isActive() and @_activeAreas < @_multipleSelections
        @_activate target
        @_activeAreas++
        @notifyAll 'onSelectArea', area

      # clicking active area => deactivate it
      else if area.isActive()
        @_deactivate target
        @_activeAreas--
        @notifyAll 'onDeselectArea', area

  # ============================================================================
  _activate: (target) =>
    # center on the map
    @_map.fitBounds target.getBounds()

    # animate color to active state
    @_animate target, {
      'fill': HGConfig.color_active.val
    }, ANIMATION_DURATION

    target.hgArea.activate()
    @_activeTarget = target

  # ============================================================================
  _deactivate: (target) =>
    if target?  # accounts for the case that there is no active area

      # animate color back to normal state
      @_animate target, {
        'fill': HGConfig.color_white.val
      }, ANIMATION_DURATION

      target.hgArea.deactivate()
      @_activeTarget = null

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
