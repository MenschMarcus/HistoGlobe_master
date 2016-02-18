window.HG ?= {}

DEBUG = no
FOCUS = no

class HG.AreasOnMap

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onSelectArea'
    @addCallback 'onDeselectArea'

    # init variables
    @_focusMode = yes         # can areas be focused (onHover)?
    @_numSelections = 1       # 1 = single-selection mode, 2..n = multiple-selection mode (maximum number of selections)
    @_selectedAreas = []      # for multiple-selection mode: save array of selected areas [{id, target, area}]
                              # in single-selection mode this array has only one object -> the 1 selected area
  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add areasOnMap to HG instance
    @_hgInstance.areasOnMap = @

    # init variables
    @_map = @_hgInstance.map._map

    # event handling
    @_hgInstance.onAllModulesLoaded @, () =>

      if @_hgInstance.areaController

        # change of areas
        @_hgInstance.areaController.onAddArea @, (area) =>
          @_addGeom area
          @_addName area
          @_colorArea area
        # @_areaController.onRemoveArea @, (id) =>    @_removeArea id

      else
        console.error "Unable to show areas on Map: AreaController module not detected in HistoGlobe instance!"

      # DEBUG OUTPUT
      # as = []
      # as.push a.getNames().commonName for a in @_selectedAreas
      # console.log "AM onStartEdi) ", as

      # switch to multiple-selection mode
      @_hgInstance.editController?.onStartAreaSelection @, (num) =>
        @_numSelections = num     # can receive a number (1, 2, 3, ... , MAX_NUM)

      # switch to single-selection mode
      @_hgInstance.editController?.onFinishAreaSelection @, () =>
        @_numSelections = 1       # 1 = single selection

      # switch to focus mode
      # = areas are highlighted on hover and can be selected
      @_hgInstance.editController?.onStartAreaEdit @, () =>
        @_focusMode = no

      # switch to no-focus mode
      # = areas are not highlighted and can not be selected
      @_hgInstance.editController?.onFinishAreaEdit @, () =>
        @_focusMode = yes


      @_hgInstance.editController?.onAddArea @, (area) =>
        @_addGeom area
        @_addName area
        @_colorArea area

      @_hgInstance.editController?.onUpdateArea @, (area) =>
        @_removeName area
        @_removeGeom area
        @_addGeom area
        @_addName area
        @_colorArea area

      @_hgInstance.editController?.onRemoveArea @, (area) =>
        @_removeGeom area
        @_removeName area


  # ============================================================================
  getSelectedAreas: () ->  @_selectedAreas


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  # physically adds area to the map, but makes it invisible
  _addGeom: (area) ->
    # setup territory
    unless area.geomLayer?

      # create area as leaflet layer -> clickable and class name to style it in css
      # setting class to area and style it with css is a bad idea,
      # because d3 can not update that => use leaflet layer options
      # NB! different vocabulary for leaflet layers and svg paths (animated by d3)
      #   property          leaflet       svg
      #   area color        fillColor     fill
      #   area opacity      fillOpacity   fill-opacity
      #   border color      color         stroke
      #   border opacity    opacity       stroke-opacity
      #   border width      weight        stroke-width

      options = {       # standard case: normal mode, non-active, unfocused
        'className':    'area'
        'clickable':    true
        'fillColor':    HGConfig.color_white.val
        'fillOpacity':  HGConfig.area_full_opacity.val
        'color':        HGConfig.color_bg_dark.val
        'opacity':      HGConfig.border_opacity.val
        'weight':       HGConfig.border_width.val
      }

      area.geomLayer = L.multiPolygon area.getGeometry(), options

      # interaction
      area.geomLayer.on 'mouseover', @_onFocus
      area.geomLayer.on 'mouseout', @_onUnfocus
      area.geomLayer.on 'click', @_onClick

      # create double-link: leaflet layer knows HG area and HG area knows leaflet layer
      area.geomLayer.hgArea = area
      area.geomLayer.addTo @_map

      # add to selected areas, if it is selected
      if area.isSelected()
        @_selectedAreas.push area
      # delete from selected areas, if it is not selected
      else
        idx = @_selectedAreas.indexOf area
        @_selectedAreas.splice idx, 1 unless idx is -1


  # ============================================================================
  # physically adds label to the map, but makes it invisible
  _addName: (area) ->
    if not area.nameLayer? and area.getNames().commonName?

      # create label with name and position
      area.nameLayer = new L.Label()
      area.nameLayer.setContent @_addLinebreaks area.getNames().commonName
      area.nameLayer.setLatLng area.getCenter()

      # create double-link: leaflet label knows HG area and HG area knows leaflet label
      area.nameLayer.hgArea = area
      @_map.showLabel area.nameLayer

      # make label invisible
      # TODO: reimplment label visibility algorithm
      # area.nameLayerIsVisible = true

      # put text in center of label
      area.nameLayer.options.offset = [
        -area.nameLayer._container.offsetWidth/2,
        -area.nameLayer._container.offsetHeight/2
      ]
      area.nameLayer._updatePosition()

  # ============================================================================
  # remove geometry from map
  _removeGeom: (area) ->
    if area.geomLayer?
      # remove double-link: leaflet layer from area and area from leaflet layer
      @_map.removeLayer area.geomLayer
      area.geomLayer = null
      # remove from selected areas, if it was selected
      if area.isSelected()
        @_selectedAreas.splice (@_selectedAreas.indexOf area), 1


  # ============================================================================
  _removeName: (area) ->
    if area.nameLayer?
      # remove double-link: leaflet layer from area and area from leaflet layer
      @_map.removeLayer area.nameLayer
      area.nameLayer = null


  ### EVENTS ###
  # DEBUG OUTPUT:
  # console.log area.getCommName(), ' focusMode? ', @_focusMode, ' selected? ', area.isSelected(), ' focused? ', area.isFocused(), ' treated? ', area.isTreated()

  # ============================================================================
  _onFocus: (evt) =>
    if @_focusMode is on
      area = evt.target.hgArea
      area.focus()
      @_colorArea area

  # ============================================================================
  _onUnfocus: (evt) =>
    area = evt.target.hgArea
    area.unfocus()
    @_colorArea area

  # ============================================================================
  _onClick: (evt) =>
    if @_focusMode is on
      area = evt.target.hgArea

      # area is selected => deselect
      if area.isSelected()
        @_deselect area

      # area is deselected => select
      else
        # single-selection mode: only one area can be activated it and deactivate currently active area
        @_deselect @_selectedAreas[0] if @_numSelections is 1
        # multiple-selection mode: just select another one -> if there is still space for one more
        @_select area if @_selectedAreas.length < @_numSelections

      # bug: after clicking, it is assumed to be still focused
      # fix: unfocus afterwards
      @_onUnfocus evt

      console.log area.getId(), area.isSelected()

  # ============================================================================
  _select: (area) =>
    # change in model
    area.select()
    @_selectedAreas.push area
    # change in view
    @_colorArea area
    @_map.fitBounds area.geomLayer.getBounds() if FOCUS
    # tell everyone
    @notifyAll 'onSelectArea', area

  # ============================================================================
  _deselect: (area) =>
    if area?  # accounts for the case that there is no active area
      # change in model
      area.deselect()
      @_selectedAreas.splice (@_selectedAreas.indexOf area), 1 # remove Area from array
      # change in view
      @_colorArea area
      @_map.fitBounds area.geomLayer.getBounds() if FOCUS
      # tell everyone
      @notifyAll 'onDeselectArea', area

  # ============================================================================
  _clearSelectedAreas: () ->
    for area in @_selectedAreas    # deactivate all areas from multiple selection mode
      area.deselect()
      @_colorArea area
    @_selectedAreas = []           # => no area selected. TODO: Is that right?

  # ============================================================================
  # one function does all the coloring depending on the state of the area
  _colorArea: (area) =>
    # decision tree:  focusMode?
    #               1/          \0
    #        selected?          selected?
    #        1/     \0          1/     \0
    #   focused?  focused?  treated?   |
    #    1/  \0    1/  \0    1/  \0    |

    if @_focusMode
      if area.isSelected()
        if area.isFocused()
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_highlight.val
            'fill-opacity': HGConfig.area_full_opacity.val
          }, HGConfig.animation_time.val
        else
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_active.val
            'fill-opacity': HGConfig.area_half_opacity.val
          }, HGConfig.animation_time.val
      else
        if area.isFocused()
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_highlight.val
            'fill-opacity': HGConfig.area_half_opacity.val
          }, HGConfig.animation_time.val
        else
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_white.val
            'fill-opacity': HGConfig.area_full_opacity.val
          }, HGConfig.animation_time.val
    else
      if area.isSelected()
        if area.isTreated()
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_bg_medium.val
            'fill-opacity': HGConfig.area_full_opacity.val
          }, HGConfig.animation_time.val
        else
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_bg_medium.val
            'fill-opacity': HGConfig.area_half_opacity.val
          }, HGConfig.animation_time.val
      else
        @_animate area.geomLayer, {
          'fill':         HGConfig.color_white.val
          'fill-opacity': HGConfig.area_full_opacity.val
        }, HGConfig.animation_time.val



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
