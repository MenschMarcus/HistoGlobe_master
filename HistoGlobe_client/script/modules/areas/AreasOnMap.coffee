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
    @_focusMode = on          # can areas be focused (onHover)?
    @_maxSelections = 1       # 1 = single-selection mode, 2..n = multi-selection mode (maximum number of selections)
    @_selectedAreas = []      # for multi-selection mode: save array of selected areas [{id, target, area}]
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
        @_hgInstance.areaController.onAddArea @, (area) => @addArea area

      else
        console.error "Unable to show areas on Map: AreaController module not detected in HistoGlobe instance!"

      # DEBUG OUTPUT
      # as = []
      # as.push a.getNames().commonName for a in @_selectedAreas
      # console.log "AM onStartEdi) ", as

  # ============================================================================
  # direct commands from edit operation steps

  # ----------------------------------------------------------------------------
  # switch to multi-selection mode
  startAreaSelection: (num) ->
    @_maxSelections = num     # can receive a number (1, 2, 3, ... , MAX_NUM)

  # ----------------------------------------------------------------------------
  # switch to single-selection mode
  finishAreaSelection: () ->
    @_maxSelections = 1       # 1 = single selection

  # ----------------------------------------------------------------------------
  # switch to focus mode
  # = areas are highlighted on hover and can be selected
  startAreaEdit: () ->
    @_focusMode = off
    @_colorArea area for area in @_selectedAreas

  # ----------------------------------------------------------------------------
  # switch to no-focus mode
  # = areas are not highlighted and can not be selected
  finishAreaEdit: () ->
    @_focusMode = on
    @_colorArea area for area in @_selectedAreas

  # ----------------------------------------------------------------------------
  addArea: (area) ->
    @_addGeom area
    @_addName area
    @_colorArea area

  # ----------------------------------------------------------------------------
  updateArea: (area) ->
    @_removeName area
    @_removeGeom area
    @_addGeom area
    @_addName area
    @_colorArea area

  # ----------------------------------------------------------------------------
  removeArea: (area) ->
    @_removeGeom area
    @_removeName area

  # ============================================================================
  getSelectedAreas: () ->
    @_selectedAreas

  # ----------------------------------------------------------------------------
  getAreas: () ->
    areas = []
    @_map.eachLayer (l) ->    # push all areas
      areas.push l.hgArea if l.hgArea? and not (l instanceof L.Label)
    areas


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

      area.geomLayer = new L.multiPolygon area.getGeometry().latLng(), options

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
      # TODO: set back @_addLinebreaks
      area.nameLayer.setContent area.getNames().commonName
      area.nameLayer.setLatLng area.getLabelPosition(yes)

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
    area = evt.target.hgArea

    # single-selection mode
    if @_maxSelections is 1

      # area is selected => deselect
      if area.isSelected()
        @_deselect area

      # area is deselected => deselect selected area(s) + select this one
      else
        @_deselect area for area in @_selectedAreas
        @_select area

    # multi-selection mode
    else

      # if maximum number of selections not reached => add it
      if @_selectedAreas.length < @_maxSelections
        @_select area

    # bug: after clicking, it is assumed to be still focused
    # fix: unfocus afterwards
    @_onUnfocus evt

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
  # one function does all the coloring depending on the state of the area
  # this was SO hard to come up with. Please no major changes
  # -> it will be a pain in the ***
  _colorArea: (area) =>
    # decision tree:  focusMode?
    #               1/          \0
    #        selected?          selected?
    #        1/     \0          1/     \0
    #   focused?  focused?  treated?   |
    #    1/  \0    1/  \0    1/  \0    |
    #                          focused?
    #                          1/   \0

    if @_focusMode
      if area.isSelected()
        if area.isFocused()
          # focus mode -> selected + focussed (hover active)
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_highlight.val
            'fill-opacity': HGConfig.area_full_opacity.val
          }, HGConfig.animation_time.val
        else
          # focus mode -> selected + not focussed (active)
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_active.val
            'fill-opacity': HGConfig.area_half_opacity.val
          }, HGConfig.animation_time.val
      else
        if area.isFocused()
          # focus mode -> not selected + focussed (hover)
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_highlight.val
            'fill-opacity': HGConfig.area_half_opacity.val
          }, HGConfig.animation_time.val
        else
          # focus mode -> not selected + not focussed (normal)
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_white.val
            'fill-opacity': HGConfig.area_full_opacity.val
          }, HGConfig.animation_time.val
    else
      if area.isSelected()
        if area.isTreated()
          # edit mode -> selected + treated (done)
          @_animate area.geomLayer, {
            'fill':         HGConfig.color_active.val
            'fill-opacity': HGConfig.area_full_opacity.val
          }, HGConfig.animation_time.val
        else
          # edit mode -> selected + not treated + focussed (hover -> currently treating)
          if area.isFocused()
            @_animate area.geomLayer, {
              'fill':         HGConfig.color_highlight.val
              'fill-opacity': HGConfig.area_full_opacity.val
            }, HGConfig.animation_time.val
          # edit mode -> selected + not treated + not focussed (to be treated)
          else
            @_animate area.geomLayer, {
              'fill':         HGConfig.color_active.val
              'fill-opacity': HGConfig.area_half_opacity.val
            }, HGConfig.animation_time.val
      else
        # edit mode -> not selected (normal)
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