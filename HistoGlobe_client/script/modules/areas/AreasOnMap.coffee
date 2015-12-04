window.HG ?= {}

class HG.AreasOnMap

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  NUM_LABEL_PRIOS = 5
  TRANS_COLOR = '#D5C900'
  TRANS_COLOR_HC = '#2f3b64'

  # ============================================================================
  constructor: (config) ->
    @_map             = null
    @_areaController  = null

    # label handling
    # 2 arrays of 6 arrays (one for each label priority, 0 is empty and is ignored, so that prio value matched array index)
    # one for all visible, one for all invisible labels
    @_visibleLabels   = []
    @_invisibleLabels = []
    i = 0
    while i <= NUM_LABEL_PRIOS
      @_visibleLabels.push []
      @_invisibleLabels.push []
      ++i

    # highcontrast hack: swap between normal and "_hc" mode
    @_inHighContrast  = no

    defaultConfig =
      labelVisibilityFactor: 5

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (hgInstance) ->

    hgInstance.areasOnMap = @

    @_aniTime = hgInstance._config.areaAniTime
    @_map = hgInstance.map._map
    @_areaController = hgInstance.areaController

    @_zoomLevel = @_map.getZoom()

    # event handling
    if @_areaController

      # change of areas
      @_areaController.onAddArea @, (area) =>
        @_addArea area
        @_showArea area, @_aniTime

      @_areaController.onRemoveArea @, (area) =>
        @_hideArea area, @_aniTime

      @_areaController.onUpdateAreaStyle @, (area, isHC) =>
        @_inHighContrast = isHC
        @_updateAreaStyle area, @_aniTime

      # transition areas and borders
      @_areaController.onFadeInArea @, (area, isHighlight) =>
        @_addArea area
        @_showArea area, @_aniTime, isHighlight

      @_areaController.onFadeOutArea @, (area) =>
        @_hideArea area, @_aniTime

      @_areaController.onFadeInBorder @, (border) =>
        @_addBorder border
        @_showBorder border, @_aniTime

      @_areaController.onFadeOutBorder @, (border) =>
        @_hideBorder border, @_aniTime

      # change of labels
      @_areaController.onAddLabel @, (label) =>
        @_addLabel label

      @_areaController.onRemoveLabel @, (label) =>
        @_removeLabel label

      @_areaController.onUpdateLabelStyle @, (label, isHC) =>
        @_inHighContrast = isHC
        @_updateLabelStyle label

      @_map.on "zoomend", @_updateLabels

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
      options = @_translateAreaStyle area.getStyle()
      options.fillOpacity = 0
      options.lineOpacity = 0
      options.clickable = no

      # create layer with loaded geometry and style
      area.myLeafletLayer = L.multiPolygon area.getGeometry(), options

      # hack: disable interaction with countries
      # area.myLeafletLayer.on "mouseover", @_onHover     # TODO: why does hover not work?
      # area.myLeafletLayer.on "mouseout", @_onUnHover
      # area.myLeafletLayer.on "click", @_onClick

      # create double-link: leaflet layer knows HG area and HG area knows leaflet layer
      area.myLeafletLayer.hgArea = area
      area.myLeafletLayer.addTo @_map

  # ============================================================================
  # physically removes area from the map
  _removeArea: (area) ->
    if area.myLeafletLayer?

      # disable event handling on the area
      # area.myLeafletLayer.off "click", @_onClick
      # area.myLeafletLayer.off "mouseover", @_onHover
      # area.myLeafletLayer.off "mouseout", @_onUnHover

      # remove double-link: leaflet layer from area and area from leaflet layer
      @_map.removeLayer area.myLeafletLayer if area.myLeafletLayer?
      area.myLeafletLayer = null

  # ============================================================================
  # slowly fades in area and allows interaction with it
  _showArea: (area, aniTime, isHighlight) ->
    if area.myLeafletLayer?
      if not isHighlight
        @_animate area.myLeafletLayer,
          "fill-opacity":   area.getStyle().areaOpacity
          "stroke-opacity": area.getStyle().borderOpacity
        , aniTime

      else
        @_animate area.myLeafletLayer,
          "fill":           if @_inHighContrast then TRANS_COLOR_HC else TRANS_COLOR
          "fill-opacity":   1.0
        , aniTime

  # ============================================================================
  _hideArea: (area, aniTime) ->
    if area.myLeafletLayer?

      # problem: transition is applied on each subpolygon of polypolygon, but callback fires after first subpolygon is succesfully animated to
      # solution: count until all subpolygons are ready faded in, then execute callback
      @_animate area.myLeafletLayer,
        # TODO: does that work better? translating the whole style 5 times for each item separately seems not intuitive...
        "fill-opacity":   0
        "stroke-opacity": 0
      , aniTime, () =>
        @_removeArea area

  # ============================================================================
  _updateAreaStyle: (area, aniTime) ->
    if area.myLeafletLayer?
      @_animate area.myLeafletLayer,
        # TODO: does that work better? translating the whole style 5 times for each item separately seems not intuitive...
        "fill":           (@_translateAreaStyle area.getStyle()).fillColor
        "fill-opacity":   (@_translateAreaStyle area.getStyle()).fillOpacity
        "stroke":         (@_translateAreaStyle area.getStyle()).color     # if in doubt: (@_translateAreaStyle area.getStyle()).lineColor
        "stroke-opacity": (@_translateAreaStyle area.getStyle()).opacity   # if in doubt: (@_translateAreaStyle area.getStyle()).lineOpacity
        "stroke-width":   (@_translateAreaStyle area.getStyle()).weight
      , aniTime

  # ============================================================================
  _updateLabelStyle: (label) ->
    if label.myLeafletLabel?
      newStyle = label.getStyle()
      label.myLeafletLabel._container.style.color = newStyle.labelColor
      label.myLeafletLabel._container.style.opacity = newStyle.labelOpacity


  # ============================================================================
  # BORDERS
  # ============================================================================

  # ============================================================================
  # physically adds border to the map, but makes it invisible
  _addBorder: (border) ->
    if not border.myLeafletLayer?

      # take style of country but make it invisible
      options = {}
      options.color       = if @_inHighContrast then TRANS_COLOR_HC else TRANS_COLOR
      options.fillColor   = if @_inHighContrast then TRANS_COLOR_HC else TRANS_COLOR
      options.opacity     = 0.0
      options.fillOpacity = 0.0
      options.weight      = 2.5
      options.clickable   = no

      # create layer with loaded geometry and style
      border.myLeafletLayer = L.multiPolyline border.getGeometry(), options

      # create double-link: leaflet layer knows HG area and HG area knows leaflet layer
      border.myLeafletLayer.hgArea = border
      border.myLeafletLayer.addTo @_map

  # ============================================================================
  # physically removes area from the map
  _removeBorder: (border) ->
    if border.myLeafletLayer?

      # remove double-link: leaflet layer from area and area from leaflet layer
      @_map.removeLayer border.myLeafletLayer
      border.myLeafletLayer = null

  # ============================================================================
  # slowly fades in area and allows interaction with it
  _showBorder: (border, aniTime) ->
    if border.myLeafletLayer?
      @_animate border.myLeafletLayer,
        "fill-opacity":   1.0
        "stroke-opacity": 1.0
      , aniTime

  # ============================================================================
  _hideBorder: (border, aniTime) ->
    if border.myLeafletLayer?
      @_animate border.myLeafletLayer,
        # TODO: does that work better? translating the whole style 5 times for each item separately seems not intuitive...
        "fill-opacity":   0.0
        "stroke-opacity": 0.0
      , aniTime, () =>
        @_removeBorder border



  # ============================================================================
  # LABELS
  # ============================================================================


  # ============================================================================
  _addLabel: (label) ->
    if not label.myLeafletLabel?
      # create invisible label with name and position
      label.myLeafletLabel = new L.Label()
      label.myLeafletLabel.setContent @_addLinebreaks label.getName()
      label.myLeafletLabel.setLatLng label.getPosition()
      label.myLeafletLabel.options.className = "invisible"   # makes label invisible onLoad

      # add label to map
      @_map.showLabel label.myLeafletLabel

      # put in center of label
      label.myLeafletLabel.options.offset = [
        -label.myLeafletLabel._container.offsetWidth/2,
        -label.myLeafletLabel._container.offsetHeight/2
      ]
      label.myLeafletLabel._updatePosition()

      @_updateLabelStyle label

      # show if visible label
      @_checkLabelOnAdd label

  # ============================================================================
  _removeLabel: (label) ->
    if label.myLeafletLabel?
      # remove double-link: leaflet label from HG label and HG label from leaflet label
      @_map.removeLayer label.myLeafletLabel
      label.myLeafletLabel = null

      # remove from visible or invisible list
      @_removeLabelFromList @_visibleLabels, label
      @_removeLabelFromList @_invisibleLabels, label

      @_checkLabelOnRemove

  # ============================================================================
  _showLabel: (label) =>
    if label.myLeafletLabel?
      label.myLeafletLabelIsVisible = true
      $(label.myLeafletLabel._container).removeClass("invisible")

      # add to visible label list
      @_addLabelToList @_visibleLabels, label

      # remove from invisible label list (if it exists)
      @_removeLabelFromList @_invisibleLabels, label

  # ============================================================================
  _hideLabel: (label) =>
    if label.myLeafletLabel?
      label.myLeafletLabelIsVisible = false
      $(label.myLeafletLabel._container).addClass("invisible")

      # add to invisible label list
      @_addLabelToList @_invisibleLabels, label

      # remove from visible label list (if it exists)
      @_removeLabelFromList @_visibleLabels, label

  # ============================================================================
  _checkLabelOnAdd: (labelA) ->
    # error handling
    return if not labelA?

    # idea: check for each label with higher priority if it collides
    # -> if so: hide
    i = labelA.getPriority()+1
    while i <= NUM_LABEL_PRIOS
      for labelB in @_visibleLabels[i]
        if @_labelsCollide labelA, labelB
          @_hideLabel labelA
          return
      ++i

    # -> if it does not collide: show
    # console.log "show", labelA.getName()
    @_showLabel labelA

    # and hide all labels with lower priority that collide
    i = labelA.getPriority()
    while i > 0
      # create list of labels that should be hidden to not remove elements from a list currently iterated through
      for labelB in @_visibleLabels[i]
        if @_labelsCollide labelA, labelB
          # console.log labelA.getName(), "hides", labelB.getName()
          @_hideLabel labelB
      --i

  # ============================================================================
  _checkLabelOnRemove: (labelA) ->
    # error handling
    return if not labelA?

    # check for all labels with lower priority if they have now space to be shown
    i = labelA.getPriority()
    while i > 0
      # create list of labels that should be shown to not add elements to a list currently iterated through
      for labelB in @_visibleLabels[i]
        if @_labelsCollide labelA, labelB
          @_showLabel labelB
      --i

  # ============================================================================
  _updateLabels: (event) =>

    # check if zoomed in or out
    zoomedIn = yes
    if @_zoomLevel > @_map.getZoom()
      zoomedIn = no
    # update zoom level
    @_zoomLevel = @_map.getZoom()

    if zoomedIn

      # check if any invisible labels have space to be shown now
      iA = NUM_LABEL_PRIOS
      while iA > 0
        for labelA in @_invisibleLabels[iA]
          if labelA?

            # check with every label with same of higher priority if it collides
            labelCollided = no
            iB = labelA.getPriority()
            while iB <= NUM_LABEL_PRIOS
              for labelB in @_invisibleLabels[iB]

                # if label collides with any other label, it can not be added
                if @_labelsCollide labelA, labelB
                  labelCollided = yes
                  break
              break if labelCollided

              ++iB

            # only if label has not collided with any other, it shall be added
            if not labelCollided
              @_showLabel labelA

        --iA


    # for both zooming in and out -> check if label have to be hidden
    # for each label check downwards if it collides
    iA = NUM_LABEL_PRIOS
    while iA > 0
      for labelA in @_visibleLabels[iA]
        if labelA?

          # check with every label of lower priority if it collides
          iB = labelA.getPriority()
          while iB > 0
            for labelB in @_visibleLabels[iB]

              # if they collide, hide the lower priority label
              if @_labelsCollide labelA, labelB
                @_hideLabel labelB

            --iB
      --iA

  # ============================================================================
  _labelsCollide: (labelA, labelB) ->
    # error handling: if one label does not exist -> abort check
    if not labelA? or not labelB?
      return false

    # error handling: if labels are the same -> abort check
    if @_areEqual labelA.getName(), labelB.getName()
      return false

    # get center, width and height for both labels
    posA = @_map.project labelA.getPosition()
    widthA = labelA.myLeafletLabel._container.clientWidth * @_labelCollisionFactor labelA.getPriority()
    heightA = labelA.myLeafletLabel._container.clientHeight * @_labelCollisionFactor labelA.getPriority()
    posB = @_map.project labelB.getPosition()
    widthB = labelB.myLeafletLabel._container.clientWidth * @_labelCollisionFactor labelB.getPriority()
    heightB = labelB.myLeafletLabel._container.clientHeight * @_labelCollisionFactor labelB.getPriority()

    # On each axis, check to see if the centers of the boxes are close enough that they'll intersect.
    # If they intersect on both axes, then the boxes intersect. If they don't, then they don't.
    return  (Math.abs(posA.x - posB.x) * 2 < (widthA + widthB)) and
            (Math.abs(posA.y - posB.y) * 2 < (heightA + heightB))

  # ============================================================================
  _labelCollisionFactor: (prio) ->
    # idea: the lower the priority, the "larger" the label box, the earlier it gets hidden
    @_config.labelVisibilityFactor*(1/prio*NUM_LABEL_PRIOS)

  # ============================================================================
  _addLabelToList: (array, label) =>
    # check if there is an element in the list that is undefined and put label there

    # IMPORTANT: manipulation of elements in array NOT with "for elem in array"
    # -> only with direct access in a while loop
    # problem: label can be twice in an array -> to avoid that, go through whole array first,
    # memorizie potential position for inserting the label, but only unless the label is not inside yet
    len = array[label.getPriority()].length
    i = 0
    insPos = null
    foundDuplicate = no
    while i < len

      # if element in array is null or undefined, it is space for the label to be inserted here
      if not array[label.getPriority()][i]?
        insPos = i

      # check if label is already in the array
      if array[label.getPriority()][i]?
        labelA = array[label.getPriority()][i].getName()
        labelB = label.getName()
        if @_areEqual labelA, labelB
          foundDuplicate = yes
      ++i

    # only if label is not in the array yet, it will be added
    if not foundDuplicate
      array[label.getPriority()][insPos] = label

      # if empty space in array found, append label to the end
      if not insPos?
        array[label.getPriority()].push label

  # ============================================================================
  _removeLabelFromList: (array, label) =>
    # check is label is actually in the array

    # TODO: sometimes labels do not get deleted correctly

    # IMPORTANT: manipulation of elements in array NOT with "for elem in array"
    # -> only with direct access in a while loop
    len = array[label.getPriority()].length
    i = 0
    while i < len

      # if element in array exists, compare its label name with the input label name
      if array[label.getPriority()][i]?
        labelA = array[label.getPriority()][i].getName()
        labelB = label.getName()

        # "removing" from array = setting it to null
        if @_areEqual labelA, labelB
          array[label.getPriority()][i] = null
          break

      ++i

  # ============================================================================
  _updateLabelStyle: (label) ->
    style = label.getStyle()
    if label.myLeafletLabel?
      label.myLeafletLabel._container.style.color = style.labelColor
      label.myLeafletLabel.setOpacity style.labelOpacity


  # ============================================================================
  # HELPER
  # ============================================================================


  # ============================================================================
  _animate: (area, attributes, duration, finishFunction) ->
    if area._layers?
      for id, path of area._layers
        d3.select(path._path).transition().duration(duration).attr(attributes).each("end", finishFunction)
    else if area._path?
      d3.select(area._path).transition().duration(duration).attr(attributes).each("end", finishFunction)

  # ============================================================================
  _onHover: (event) =>
    return
    # @_animate event.target, {"fill": "#{event.target.hgArea.getHighlightStyle().areaColor}"}, 150
    # TODO: for countries with white labels, hovering means the country name is not readable
    # -> how to get the label of the current layer I am hovering? How to change its color?

  # ============================================================================
  _onUnHover: (event) =>
    @_animate event.target, {"fill": "#{event.target.hgArea.getStyle().areaColor}"}, 150

  # ============================================================================
  _onClick: (event) =>
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
  # user centered styling (area, border, name) -> leaflet styling options

  _translateAreaStyle: (userStyle) ->
    options =
      fillColor:    userStyle.areaColor
      fillOpacity:  userStyle.areaOpacity
      lineColor:    userStyle.borderColor
      lineOpacity:  userStyle.borderOpacity
      weight:       userStyle.borderWidth
      labelOpacity: userStyle.labelOpacity
      labelColor:   userStyle.labelColor
      # backup styling for whatsoever weird browser that can only handle them
      color:        userStyle.borderColor
      opacity:      userStyle.borderOpacity

    # override in highContrast mode
    if @_inHighContrast
      options.fillColor   = userStyle.areaColor_hc
      options.lineColor   = userStyle.borderColor_hc
      options.color       = userStyle.borderColor_hc
      options.labelColor  = userStyle.labelColor_hc

    options

  # ============================================================================
  _areEqual: (str1, str2) ->
    (str1?="").localeCompare(str2) is 0

  ##############################################################################
  #                             DEBUG FUNCTIONS
  ##############################################################################


  # ============================================================================
  _checkArrayStatus: (text) ->
    invis = 0
    vis = 0
    i = 1
    while i <= NUM_LABEL_PRIOS
      for elem in @_visibleLabels[i]
        ++vis if elem?
      for elem in @_invisibleLabels[i]
        ++invis if elem?
      ++i
    console.log text, vis, invis, vis+invis

  # ============================================================================
  _checkPrioArray: (prio) ->
    console.log "VISIBLE"
    for elem in @_visibleLabels[prio]
      if elem?
        console.log "-->", elem.getName()
      else
        console.log "--> null"
    console.log "INVISIBLE"
    for elem in @_invisibleLabels[prio]
      if elem?
        console.log "-->", elem.getName()
      else
        console.log "--> null"
