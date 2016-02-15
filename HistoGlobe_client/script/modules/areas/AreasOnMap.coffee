window.HG ?= {}

DEBUG = yes
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

    @addCallback 'onActivateArea'
    @addCallback 'onDeactivateArea'
    @addCallback 'onSelectArea'
    @addCallback 'onDeselectArea'

    # init variables
    @_focusMode = yes                     # can areas be focused (onHover)?
    @_numSelections = 1                   # 1 = single-selection mode, 2..n = multiple-selection mode (maximum number of selections)
    @_selectedAreas = new HG.ObjectArray  # for multiple-selection mode: save array of selected areas [{id, target, area}]
                                          # in single-selection mode this array has only one object -> the 1 selected area
  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add areasOnMap to HG instance
    @_hgInstance.areasOnMap = @

    # init variables
    @_map = @_hgInstance.map._map

    # event handling
    if @_hgInstance.areaController

      # change of areas
      @_hgInstance.areaController.onAddArea @, (area) =>
        @_addGeom area
        @_addName area
      # @_areaController.onRemoveArea @, (id) =>    @_removeArea id

    else
      console.error "Unable to show areas on Map: AreaController module not detected in HistoGlobe instance!"


    if @_hgInstance.editController

      # switch to multiple-selection mode
      @_hgInstance.editController.onEnterOldAreaSelection @, (num) =>
        @_numSelections = num     # can receive a number (1, 2, 3, ... , MAX_NUM)

      # switch to single-selection mode
      @_hgInstance.editController.onFinishOldAreaSelection @, () =>
        @_numSelections = 1       # 1 = single selection
        @_clearSelectedAreas()

      # switch to no-focus mode
      # = areas are not highlighted and can not be selected
      @_hgInstance.editController.onEnterNewGeometrySelection @, () =>
        @_focusMode = no
        @_selectedAreas.foreach (obj) =>
          @_colorArea obj

      # switch to focus mode
      # = areas are highlighted on hover and can be selected
      @_hgInstance.editController.onFinishNewGeometrySelection @, () =>
        @_focusMode = yes
        @_selectedAreas.foreach (obj) =>
          @_colorArea obj

      # add new areas
      @_hgInstance.editController.onAddGeometry @, (obj) =>
        @_addGeom obj.area

      # remove new areas
      @_hgInstance.editController.onRemoveGeometry @, (obj) =>
        @_removeGeom obj.area

      # add new areas
      @_hgInstance.editController.onAddName @, (obj) =>
        @_addGeom obj.area

      # remove new areas
      @_hgInstance.editController.onRemoveName @, (obj) =>
        @_removeGeom obj.area


  # ============================================================================
  getSelectedAreas: () ->
    areas = []
    areas.push obj.area for obj in @_selectedAreas
    areas


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  # physically adds area to the map, but makes it invisible
  _addGeom: (area) ->
    # setup territory
    if not area.geomLayer?

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

      @_colorArea area


  # ============================================================================
  # physically adds label to the map, but makes it invisible
  _addName: (area) ->
    if not area.nameLayer?

      # create label with name and position
      area.nameLayer = new L.Label()
      area.nameLayer.setContent @_addLinebreaks area.getCommonName()
      area.nameLayer.setLatLng area.getLabelPos()

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
  _removeGeom: (id) ->
    if area.geomLayer?
      # remove double-link: leaflet layer from area and area from leaflet layer
      @_map.removeLayer area.geomLayer
      area.geomLayer = null


  # ============================================================================
  _removeName: (id) ->
    if area.nameLayer?
      # remove double-link: leaflet layer from area and area from leaflet layer
      @_map.removeLayer area.nameLayer
      area.nameLayer = null


  ### EVENTS ###
  # DEBUG OUTPUT:
  # console.log obj.area.getCommName(), ' focusMode? ', @_focusMode, ' selected? ', obj.area.isSelected(), ' focused? ', obj.area.isFocused(), ' treated? ', obj.area.isTreated()

  # ============================================================================
  _onFocus: (evt) =>
    if @_focusMode is on
      obj = @_evtToAreaObj evt
      obj.area.focus()
      @_colorArea obj

  # ============================================================================
  _onUnfocus: (evt) =>
    obj = @_evtToAreaObj evt
    obj.area.unfocus()
    @_colorArea obj

  # ============================================================================
  _onClick: (evt) =>
    if @_focusMode is on
      obj = @_evtToAreaObj evt

      # area is selected => deselect
      if obj.area.isSelected()
        @_deselect obj

      # area is deselected => select
      else
        # single-selection mode: only one area can be activated it and deactivate currently active area
        @_deselect @_selectedAreas.getByIdx 0 if @_numSelections is 1
        # multiple-selection mode: just select another one -> if there is still space for one more
        @_select obj if @_selectedAreas.num() < @_numSelections

      # bug: after clicking, it is assumed to be still focused
      # fix: unfocus afterwards
      @_onUnfocus evt

  # ============================================================================
  _select: (obj) =>
    # change in model
    obj.area.select()
    @_selectedAreas.push obj
    # change in view
    @_colorArea obj
    @_map.fitBounds obj.target.getBounds() if FOCUS
    # tell everyone
    @notifyAll 'onSelectArea', obj

  # ============================================================================
  _deselect: (obj) =>
    if obj?  # accounts for the case that there is no active area
      # change in model
      obj.area.deselect()
      @_selectedAreas.removeById obj.id
      # change in view
      @_colorArea obj
      @_map.fitBounds obj.target.getBounds() if FOCUS
      # tell everyone
      @notifyAll 'onDeselectArea', obj.id

  # ============================================================================
  _clearSelectedAreas: () ->
    for obj in @_selectedAreas    # deactivate all areas from multiple selection mode
      obj.area.deselect()
      @_colorArea obj
    @_selectedAreas.clear()       # => no area selected. TODO: Is that right?

  # ============================================================================
  # one function does all the coloring depending on the state of the area
  _colorArea: (obj) =>
    # decision tree:  focusMode?
    #               1/          \0
    #        selected?          selected?
    #        1/     \0          1/     \0
    #   focused?  focused?  treated?   |
    #    1/  \0    1/  \0    1/  \0    |

    if @_focusMode
      console.log obj if DEBUG
      console.log 'focusMode on'  if DEBUG
      if obj.area.isSelected()
        console.log '  area selected'  if DEBUG
        if obj.area.isFocused()
          console.log '    area focused'  if DEBUG
          @_animate obj.target, {
            'fill':         HGConfig.color_highlight.val
            'fill-opacity': HGConfig.area_full_opacity.val
          }, HGConfig.animation_time.val
        else
          console.log '    area not focused'  if DEBUG
          @_animate obj.target, {
            'fill':         HGConfig.color_active.val
            'fill-opacity': HGConfig.area_half_opacity.val
          }, HGConfig.animation_time.val
      else
        console.log '  area not selected'  if DEBUG
        if obj.area.isFocused()
          console.log '    area focused'  if DEBUG
          @_animate obj.target, {
            'fill':         HGConfig.color_highlight.val
            'fill-opacity': HGConfig.area_half_opacity.val
          }, HGConfig.animation_time.val
        else
          console.log '    area not focused'  if DEBUG
          @_animate obj.target, {
            'fill':         HGConfig.color_white.val
            'fill-opacity': HGConfig.area_full_opacity.val
          }, HGConfig.animation_time.val
    else
      console.log 'focusMode off'  if DEBUG
      if obj.area.isSelected()
        console.log '  area selected'  if DEBUG
        if obj.area.isTreated()
          console.log '    area treated'  if DEBUG
          @_animate obj.target, {
            'fill':         HGConfig.color_bg_medium.val
            'fill-opacity': HGConfig.area_full_opacity.val
          }, HGConfig.animation_time.val
        else
          console.log '    area not treated'  if DEBUG
          @_animate obj.target, {
            'fill':         HGConfig.color_bg_medium.val
            'fill-opacity': HGConfig.area_half_opacity.val
          }, HGConfig.animation_time.val
      else
        console.log '  area not selected'  if DEBUG
        @_animate obj.target, {
          'fill':         HGConfig.color_white.val
          'fill-opacity': HGConfig.area_full_opacity.val
        }, HGConfig.animation_time.val



  # ============================================================================
  _evtToAreaObj: (evt) =>
    return {
      id:     evt.target.hgArea.getId()
      area:   evt.target.hgArea
      target: evt.target
    }


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
