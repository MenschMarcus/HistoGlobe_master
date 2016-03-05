window.HG ?= {}

# debug output?
DEBUG = no

class HG.AreaController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onCreateAreaGeometry'
    @addCallback 'onCreateAreaName'

    @addCallback 'onUpdateAreaGeometry'
    @addCallback 'onUpdateAreaName'
    @addCallback 'onUpdateAreaStatus'

    @addCallback 'onRemoveAreaGeometry'
    @addCallback 'onRemoveAreaName'

    @addCallback 'onSelectArea'
    @addCallback 'onDeselectArea'



    # handle config
    defaultConfig =
      JSONPaths: undefined,

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (@_hgInstance) ->
    @_hgInstance.areaController = @


    @_areas = []                  # set of all HG.Area's (id, geometry, name)
    @_activeAreas = []            # set of all HG.Area's currently active

    @_maxSelections = 1           # 1 = single-selection mode, n = multi-selection mode
    @_selectedAreas = []          # array of all currently active areas
    @_areaEditMode = off          # in edit mode normal areas can not be selected
    @_editAreas = []              # stores all areas that are currently in edit mode


    @_hgInstance.onAllModulesLoaded @, () =>

      # get area view (currently active viewers for the area)
      areaViewer = []             # all viewer classes manipulating and viewing areas
      areaViewer.push @_hgInstance.areasOnMap     if @_hgInstance.areasOnMap?
      areaViewer.push @_hgInstance.areasOnGlobe   if @_hgInstance.areasOnGlobe?

      ### INIT AREAS ###
      # initially load them from file
      # TODO: exchange with real fetcching from the database
      geometryReader = new HG.GeometryReader

      for file in @_config.JSONPaths
        $.getJSON file, (areas) =>
          for area in areas.features
            id = area.id
            geometry = geometryReader.read area.geometry
            # TODO: better name handling
            name = area.properties.name
            # error handling: each area must have valid geometry
            if geometry.isValid()
              newArea = new HG.Area id, geometry, name
              @_areas.push newArea
              @_activeAreas.push newArea
              @notifyAll 'onCreateAreaGeometry', newArea
              @notifyAll 'onCreateAreaName', newArea


      ### INTERFACE ###

      # ========================================================================
      ## listen to each viewer (have the same interface)
      for view in areaViewer

        # ----------------------------------------------------------------------
        # hover areas => focus?
        view.onFocusArea @, (area) ->

          # error handling: ignore if area is already focused
          return if area.isFocused()

          # edit mode: only unselected areas in edit mode can be focused
          if @_areaEditMode is on
            if (area.isInEdit()) and (not area.isSelected())
              area.focus()
              @notifyAll 'onUpdateAreaStatus', area

          # normal mode: each area can be hovered
          else  # @_areaEditMode is off
            area.focus()
            @notifyAll 'onUpdateAreaStatus', area


        # ----------------------------------------------------------------------
        # unhover areas => unfocus!
        view.onUnfocusArea @, (area) ->

          # error handling: ignore if area is not focused
          return if not area.isFocused()

          # in both normal and edit mode: unfocus any area
          area.unfocus()
          @notifyAll 'onUpdateAreaStatus', area


        # ----------------------------------------------------------------------
        # click area => (de)select
        view.onSelectArea @, (area) ->

          # area must be focussed in order for it to be selected
          # => no distinction between edit mode and normal mode necessary anymore
          return if not area.isFocused()

          # single-selection mode: toggle selected area
          if @_maxSelections is 1

            # area is selected => deselect
            if area.isSelected()
              area.deselect()
              @_selectedAreas = []
              @notifyAll 'onDeselectArea', area

            # area is deselected => toggle currently selected area <-> new selection
            else  # not area.isSelected()

              # deselect currently selected area
              if @_selectedAreas.length is 1
                @_selectedAreas[0].deselect()
                @notifyAll 'onDeselectArea', @_selectedAreas[0]
                # no update of @_selectedAreas, because it will happen afterwards

              # select new area
              area.select()
              @_selectedAreas[0] = area
              @notifyAll 'onSelectArea', area


          # multi-selection mode: add to selected area until max limit is reached
          else  # @_maxSelections > 1

            # area is selected => deselect
            if area.isSelected()
              area.deselect()
              @_selectedAreas.splice (@_selectedAreas.indexOf area), 1
              @notifyAll 'onDeselectArea', area

            else  # not area.isSelected()
              # if maximum number of selections not reached => select it
              if @_selectedAreas.length < @_maxSelections
                area.select()
                @_selectedAreas.push area
                @notifyAll 'onSelectArea', area


          @_DEBUG_OUTPUT 'select area (from view)' if DEBUG

      # ========================================================================
      ## listen to Edit Mode

      # ========================================================================
      # swap single-selection <-> multi-selection mode

      @_hgInstance.editMode.onEnableMultiSelection @, (num) ->

        # error handling: must be a number and can not be smaller than 1
        if (num < 1) or (isNaN num)
          return console.error "There can not be less than 1 area selected"

        # set maximum number of selections
        @_maxSelections = num

        # if there has been an area already selected in single-selection mode
        # it will still be in the @_selectedAreas array and can stay there,
        # since it will never be deselected

        @_DEBUG_OUTPUT 'enable multi selection' if DEBUG

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDisableMultiSelection @, (selectedAreaId=null) ->

        # restore single-selection mode
        @_maxSelections = 1

        # deselect each area
        # -> except for the one specified by edit mode to be kept selected
        @_cleanSelectedAreas selectedAreaId

        @_DEBUG_OUTPUT 'disable multi selection' if DEBUG


      # ========================================================================
      # swap normal mode <-> edit mode

      @_hgInstance.editMode.onEnableAreaEditMode @, () ->
        @_areaEditMode = on
        @_maxSelections = HGConfig.max_area_selection.val

        # if there has been an area already selected in single-selection mode
        # it will still be in the @_selectedAreas array and can stay there,
        # since it will never be deselected

        @_DEBUG_OUTPUT 'start edit mode' if DEBUG

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDisableAreaEditMode @, (selectedAreaId=null) ->
        @_areaEditMode = off
        @_maxSelections = 1

        @_DEBUG_OUTPUT 'end edit mode (before)' if DEBUG

        # deselect each area
        # -> except for the one specified by edit mode to be kept selected
        @_cleanSelectedAreas selectedAreaId

        # transform each edit area into a normal area
        for area in @_editAreas

          ## update model
          area.inEdit no

          ## update view
          @notifyAll 'onUpdateAreaStatus', area

        # clear edit areas -> all transfered to active areas at this point
        @_editAreas = []

        @_DEBUG_OUTPUT 'end edit mode (after)' if DEBUG


      # ========================================================================
      # handle new, updated and old areas

      @_hgInstance.editMode.onCreateArea @, (id, geometry, name=null) ->
        # error handling: new area must have valid geometry
        return if not geometry.isValid()

        ## update model
        newArea = new HG.Area id, geometry, name
        newArea.inEdit yes

        ## update controller
        @_editAreas.push newArea
        @_activeAreas.push newArea
        @_areas.push newArea

        ## update view
        @notifyAll 'onCreateAreaGeometry', newArea
        if name
          @notifyAll 'onCreateAreaName', newArea

        @_DEBUG_OUTPUT 'create area' if DEBUG

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onUpdateAreaGeometry @, (id, geometry) ->
        area = @getArea id

        # error handling: area has to be found and have a valid geometry
        return if (not area) or (not geometry.isValid())

        ## update model
        area.setGeometry geometry
        area.resetRepresentativePoint()   # TODO: better way to adapt label position?

        ## update view
        @notifyAll 'onUpdateAreaGeometry', area
        @notifyAll 'onUpdateAreaName', area   # to account for change in label position

        @_DEBUG_OUTPUT 'update area geometry' if DEBUG

      # ------------------------------------------------------------------------
      # name and position come always together from edit mode, so both properties
      # can exceptionally be treated in the same function
      @_hgInstance.editMode.onUpdateAreaName @, (id, name=null, position=null) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        hadNameBefore = area.getName()?

        ## update model
        area.setName name

        ## update view

        # no name => delete it from the map
        if name is null
          area.resetRepresentativePoint()

          # if there was a name before => remove it
          if hadNameBefore
            @notifyAll 'onRemoveAreaName', area

          # else if there was no name before => no need to change something

        # name given => update it
        else
          area.setRepresentativePoint position if position

          # if name was there before => update
          if hadNameBefore
            @notifyAll 'onUpdateAreaName', area

          # if there was no name before => create if
          else
            @notifyAll 'onCreateAreaName', area

        @_DEBUG_OUTPUT 'update area name' if DEBUG

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onStartEditArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        ## update model
        area.inEdit yes

        ## update controller
        idx = @_editAreas.indexOf area
        if idx is -1 # = if area is not in array
          @_editAreas.push area

          ## update view
          @notifyAll 'onUpdateAreaStatus', area

        @_DEBUG_OUTPUT 'start edit mode' if DEBUG

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onEndEditArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        ## update model
        area.inEdit no

        ## update controller
        idx = @_editAreas.indexOf area
        if idx isnt -1  # = if area in array
          @_editAreas.push area

          ## update view
          @notifyAll 'onUpdateAreaStatus', area

        @_DEBUG_OUTPUT 'end edit mode' if DEBUG

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onSelectArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        ## update model
        area.select()

        ## update controller
        idx = @_selectedAreas.indexOf area
        if idx is -1 # = if area is not in array
          @_selectedAreas.push area

          ## update view
          @notifyAll 'onSelectArea', area

        @_DEBUG_OUTPUT 'select area (from edit mode)' if DEBUG

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDeselectArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        ## update model
        area.deselect()

        ## update controller
        idx = @_selectedAreas.indexOf area
        if idx isnt -1 # = if area in array
          @_selectedAreas.splice idx, 1

          ## update view
          @notifyAll 'onDeselectArea', area

        @_DEBUG_OUTPUT 'deselect area (from edit mode)' if DEBUG

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onRemoveArea @, (id, completeRemove=no) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        ## update controller

        # remove from selected array, in case it was there
        idx = @_selectedAreas.indexOf area
        @_selectedAreas.splice idx, 1 if idx isnt -1

        # remove from editAreas array, in case it was there
        idx = @_editAreas.indexOf area
        @_editAreas.splice idx, 1 if idx isnt -1

        # remove from active areas
        @_activeAreas.splice (@_activeAreas.indexOf area), 1

        # remove from all areas, in case it is a complete remove
        if completeRemove
          @_areas.splice (@_areas.indexOf area), 1

        ## update view

        # decide: remove full area (name + geometry) or is only geometry left?
        @notifyAll 'onRemoveAreaGeometry', area
        if area.getName()
          @notifyAll 'onRemoveAreaName', area

        @_DEBUG_OUTPUT 'remove area' if DEBUG

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onRestoreArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        ## update controller

        # add back to active areas
        @_activeAreas.push area

        # restore membership in edit/selected arrays
        @_editAreas.push area       if area.isInEdit()
        @_selectedAreas.push area   if area.isSelected()

        ## update view

        # put back on map
        @notifyAll 'onCreateAreaGeometry', area
        if area.getName()
          @notifyAll 'onCreateAreaName', area

        @_DEBUG_OUTPUT 'restore area' if DEBUG


  # ============================================================================
  getAreas: () ->           @_areas
  getSelectedAreas: () ->   @_selectedAreas

  # ----------------------------------------------------------------------------
  getArea: (id) ->
    for area in @_areas
      if area.getId() is id
        return area
        break
    return null

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _cleanSelectedAreas: (exceptionAreaId) ->
    # manuel while loop, because selected areas shrinks while operating in it
    loopIdx = @_selectedAreas.length-1
    while loopIdx >= 0

      area = @_selectedAreas[loopIdx]

      # special case: ignore area specified to be still active
      if area.getId() is exceptionAreaId
        loopIdx--
        continue

      # normal case: deselect
      area.deselect()
      @notifyAll 'onDeselectArea', area
      @_selectedAreas.splice loopIdx, 1

      loopIdx--

  # ============================================================================
  _DEBUG_OUTPUT: (id) ->

    sel = []
    sel.push a.getId() for a in @_selectedAreas
    edi = []
    edi.push a.getId() for a in @_editAreas

    console.log "-------------------------- ", id, "-------------------------- "
    console.log "max selections: ", @_maxSelections
    console.log "selected areas: ", sel.join(', ')
    console.log "edit mode:      ", @_areaEditMode
    console.log "edit areas:     ", edi.join(', ')
    console.log "active areas:   ", @_activeAreas.length
    console.log "=============================================================="
