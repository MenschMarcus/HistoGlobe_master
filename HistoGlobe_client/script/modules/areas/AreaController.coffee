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
    @addCallback 'onUpdateAreaGeometry'
    @addCallback 'onUpdateAreaName'
    @addCallback 'onUpdateAreaStatus'
    @addCallback 'onSelectArea'
    @addCallback 'onDeselectArea'
    @addCallback 'onRemoveArea'
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

          # edit mode: only unselected areas can be focused
          if @_areaEditMode is on
            if not area.isSelected()
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

        # error handling: number must be larger than 1
        # otherwise stay in single-selection mode
        return if num is 0

        # enable multi-selection mode
        @_maxSelections = num

        # if there has been an area already selected in single-selection mode
        # it will still be in the @_selectedAreas array and can stay there,
        # since it will never be deselected

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDisableMultiSelection @, (selectedAreaId=null) ->

        # restore single-selection mode
        @_maxSelections = 1

        # deselect each area
        # -> except for the one specified by edit mode to be kept selected

        # manuel while loop, because selected areas shrinks while operating in it
        idx = 0
        len = @_selectedAreas.length
        while idx < len

          area = @_selectedAreas[idx]

          # special case: ignore area specified to be still active
          if area.getId() is selectedAreaId
            len--
            continue

          # normal case: deselect
          area.deselect()
          # N.B. do not notify selectOldAreas step, because that would remove the areas from their internal array
          @notifyAllBut 'onDeselectArea', @_hgInstance.selectOldAreasStep, area
          @_selectedAreas.splice idx, 1

          len--


      # ========================================================================
      # swap normal mode <-> edit mode

      @_hgInstance.editMode.onEnableAreaEditMode @, () ->
        @_areaEditMode is on

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDisableAreaEditMode @, (selectedAreaId=null) ->
        @_areaEditMode is off

        # transform each edit area into a normal area and deselect it
        # -> except for the one specified by edit mode to be kept selected
        for area in @_editAreas

          # TODO: error handling here?

          ## 1) make normal
          area.inEdit no

          ## 2) deselect
          # special case: area specified to be still active to be put in selectedAreas array
          if area.getId() is selectedAreaId
            @_selectedAreas.push area
            @notifyAll 'onSelectArea', area

          # normal case: deselect
          area.deselect()

          # anyway: new status => redraw
          @notifyAll 'onUpdateAreaStatus', area

        # clear edit areas -> all transfered to active areas at this point
        @_editAreas = []


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

      # ------------------------------------------------------------------------
      # name and position come always together from edit mode, so both properties
      # can exceptionally be treated in the same function
      @_hgInstance.editMode.onUpdateAreaName @, (id, name=null, position=null) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area) or (not name)

        area.setName name
        area.setRepresentativePoint position if position
        @notifyAll 'onUpdateAreaName', area

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

        @_activeAreas.splice (@_activeAreas.indexOf area), 1

        # remove also from editAreas array, in case it was there
        idx = @_editAreas.indexOf area
        @_editAreas.splice idx, 1 if idx isnt -1

        @notifyAll 'onRemoveArea', area

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onRemoveAreaName @, (id, name=null, position=null) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        area.setName null
        area.resetRepresentativePoint()
        @notifyAll 'onRemoveAreaName', area



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