window.HG ?= {}

class HG.AreaController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onCreateArea'
    @addCallback 'onCreateAreaGeometry'
    @addCallback 'onCreateAreaName'

    @addCallback 'onUpdateAreaGeometry'
    @addCallback 'onUpdateAreaName'
    @addCallback 'onUpdateAreaStatus'

    @addCallback 'onSelectArea'
    @addCallback 'onDeselectArea'

    @addCallback 'onRemoveArea'
    @addCallback 'onRemoveAreaGeometry'
    @addCallback 'onRemoveAreaName'


    # handle config
    defaultConfig =
      JSONPaths: undefined,

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (@_hgInstance) ->
    @_hgInstance.areaController = @


    @_activeAreas = []            # set of all HG.Area's (id, geometry, name)

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
              @_activeAreas.push newArea
              @notifyAll 'onCreateArea', newArea


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
              @notifyAll 'onDeselectArea', area
              @_selectedAreas = []

            # area is deselected => toggle currently selected area <-> new selection
            else  # not area.isSelected()

              # deselect currently selected area
              if @_selectedAreas.length is 1
                @_selectedAreas[0].deselect()
                @notifyAll 'onDeselectArea', @_selectedAreas[0]
                # no update of @_selectedAreas, because it will happen afterwards

              # select new area
              area.select()
              @notifyAll 'onSelectArea', area
              @_selectedAreas[0] = area


          # multi-selection mode: add to selected area until max limit is reached
          else  # @_maxSelections > 1

            # area is selected => deselect
            if area.isSelected()
              area.deselect()
              @notifyAll 'onDeselectArea', area
              @_selectedAreas.splice (@_selectedAreas.indexOf area), 1

            else  # not area.isSelected()
              # if maximum number of selections not reached => select it
              if @_selectedAreas.length < @_maxSelections
                area.select()
                @notifyAll 'onSelectArea', area
                @_selectedAreas.push area


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

        # console.log "single-end", @_selectedAreas

        # if there has been an area already selected in single-selection mode
        # it will still be in the @_selectedAreas array and can stay there,
        # since it will never be deselected

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDisableMultiSelection @, (selectedAreaId=null) ->

        # restore single-selection mode
        @_maxSelections = 1

        # console.log "multi-start", @_selectedAreas

        # deselect each area
        # -> except for the one specified by edit mode to be kept selected

        # manuel while loop, because selected areas shrinks while operating in it
        loopIdx = @_selectedAreas.length-1
        while loopIdx >= 0

          area = @_selectedAreas[loopIdx]

          # special case: ignore area specified to be still active
          if area.getId() is selectedAreaId
            loopIdx--
            continue

          # normal case: deselect
          area.deselect()
          # N.B. do not notify selectOldAreas step, because that would remove the areas from their internal array
          @notifyAllBut 'onDeselectArea', @_hgInstance.selectOldAreasStep, area
          @_selectedAreas.splice loopIdx, 1

          loopIdx--

        # console.log "multi-end", @_selectedAreas


      # ========================================================================
      # swap normal mode <-> edit mode

      @_hgInstance.editMode.onEnableAreaEditMode @, () ->
        @_areaEditMode = on

        # console.log "edit-start", @_selectedAreas

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDisableAreaEditMode @, (selectedAreaId=null) ->
        @_areaEditMode = off

        # console.log "normal-start", @_selectedAreas

        # transform each edit area into a normal area and deselect it
        # -> except for the one specified by edit mode to be kept selected
        for area in @_editAreas

          # TODO: error handling here?

          ## 1) make normal
          area.inEdit no

          ## 2) deselect
          # special case: area specified to be still active to be put in selectedAreas array
          # error handling: area must actually still exist
          if (area.getId() is selectedAreaId) and (@getArea(area.getId()) isnt -1)
            area.select()
            @_selectedAreas.push area
            @notifyAll 'onSelectArea', area

          # normal case: deselect
          area.deselect()

          # anyway: new status => redraw
          @notifyAll 'onUpdateAreaStatus', area

        # clear edit areas -> all transfered to active areas at this point
        @_editAreas = []

        # console.log "normal-end", @_selectedAreas


      # ========================================================================
      # handle new, updated and old areas

      @_hgInstance.editMode.onCreateArea @, (id, geometry, name=null) ->
        # error handling: new area must have valid geometry
        return if not geometry.isValid()

        newArea = new HG.Area id, geometry, name
        newArea.inEdit yes
        @_editAreas.push newArea
        @_activeAreas.push newArea
        @notifyAll 'onCreateArea', newArea


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onUpdateAreaGeometry @, (id, geometry) ->
        area = @getArea id

        # error handling: area has to be found and have a valid geometry
        return if (not area) or (not geometry.isValid())

        area.setGeometry geometry
        @notifyAll 'onUpdateAreaGeometry', area

        # TODO: better way to do this?
        # adapt label position
        area.resetRepresentativePoint()
        @notifyAll 'onUpdateAreaName', area


      # ------------------------------------------------------------------------
      # name and position come always together from edit mode, so both properties
      # can exceptionally be treated in the same function
      @_hgInstance.editMode.onUpdateAreaName @, (id, name=null, position=null) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        hadNameBefore = area.getName()?

        area.setName name

        # no name => delete it from the map
        if name is null
          area.resetRepresentativePoint()
          @notifyAll 'onRemoveAreaName', area
          return

        # name given => update it (if it was there before) or create it new
        area.setRepresentativePoint position if position

        if hadNameBefore
          @notifyAll 'onUpdateAreaName', area
        else # area had no name before
          @notifyAll 'onCreateAreaName', area


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onStartEditArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        area.inEdit yes
        @notifyAll 'onUpdateAreaStatus', area
        # no usage of @_selectedAreas array in edit mode, because all areas
        # in edit mode are already in @_editAreas array

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onEndEditArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        area.inEdit no
        @notifyAll 'onUpdateAreaStatus', area
        # no usage of @_selectedAreas array in edit mode, because all areas
        # in edit mode are already in @_editAreas array


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onSelectArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        area.select()
        @notifyAll 'onSelectArea', area
        # no usage of @_selectedAreas array in edit mode, because all areas
        # in edit mode are already in @_editAreas array


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDeselectArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        area.deselect()
        @notifyAll 'onDeselectArea', area
        # no usage of @_selectedAreas array in edit mode, because all areas
        # in edit mode are already in @_editAreas array


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onRemoveArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        # remove from active areas
        @_activeAreas.splice (@_activeAreas.indexOf area), 1

        # remove also from editAreas array, in case it was there
        idx = @_editAreas.indexOf area
        @_editAreas.splice idx, 1 if idx isnt -1

        # remove also from selected array, in case it was there
        idx = @_selectedAreas.indexOf area
        @_selectedAreas.splice idx, 1 if idx isnt -1

        # decide: remove full area (name + geometry) or is only geometry left?
        if area.getName() isnt null
          @notifyAll 'onRemoveArea', area
        else
          @notifyAll 'onRemoveAreaGeometry', area


  # ============================================================================
  getAreas: () ->           @_activeAreas
  getSelectedAreas: () ->   @_selectedAreas

  # ----------------------------------------------------------------------------
  getArea: (id) ->
    for area in @_activeAreas
      if area.getId() is id
        return area
        break
    return null

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################