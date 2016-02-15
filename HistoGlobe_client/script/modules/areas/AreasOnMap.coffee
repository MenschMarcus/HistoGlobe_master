window.HG ?= {}

DEBUG = yes

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
  enableMultipleSelectionMode: (num) ->  # can receive a number (1, 2, 3, ... , MAX_NUM)
    @_numSelections = num

  disableMultipleSelectionMode: () ->
    @_numSelections = 1

  # ============================================================================
  # focus mode: on = areas are highlighted on hover and can be selected
  #             off = areas are not highlighted and can not be selected
  enterFocusMode: () ->
    @_focusMode = yes
    @_selectedAreas.foreach (obj) =>
      @_colorArea obj

  leaveFocusMode: () ->
    @_focusMode = no
    @_selectedAreas.foreach (obj) =>
      @_colorArea obj

  # ============================================================================
  getSelectedAreas: () ->
    areas = []
    areas.push obj.area for obj in @_selectedAreas
    areas

  # ============================================================================
  clearSelectedAreas: () ->
    for obj in @_selectedAreas    # deactivate all areas from multiple selection mode
      obj.area.deselect()
      @_colorArea obj
    @_selectedAreas.clear()       # => no area selected. TODO: Is that right?

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
      area.myLeafletLayer = L.multiPolygon area.getGeometry(), options

      # interaction
      area.myLeafletLayer.on 'mouseover', @_onFocus
      area.myLeafletLayer.on 'mouseout', @_onUnfocus
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
    @_map.fitBounds obj.target.getBounds() unless DEBUG
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
      @_map.fitBounds obj.target.getBounds() unless DEBUG
      # tell everyone
      @notifyAll 'onDeselectArea', obj.id

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
