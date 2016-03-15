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

    @addCallback 'onCreateGeometry'
    @addCallback 'onCreateName'

    @addCallback 'onUpdateGeometry'
    @addCallback 'onUpdateName'
    @addCallback 'onUpdateRepresentativePoint'
    @addCallback 'onUpdateStatus'

    @addCallback 'onRemoveGeometry'
    @addCallback 'onRemoveName'

    @addCallback 'onSelect'
    @addCallback 'onDeselect'


    # handle config
    defaultConfig = {}

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add module to HG instance
    @_hgInstance.areaController = @


    ### INIT MEMBERS ###
    @_activeAreas = []            # set of all HG.Area's currently active

    @_maxSelections = 1           # 1 = single-selection mode, n = multi-selection mode
    @_selectedAreas = []          # array of all currently active areas
    @_areaEditMode = off          # in edit mode normal areas can not be selected
    @_editAreas = []              # stores all areas that are currently in edit mode


    ### INTERACTION ###
    @_hgInstance.onAllModulesLoaded @, () =>

      # get area view (currently active viewers for the area)
      areaViewer = []             # all viewer classes manipulating and viewing areas
      areaViewer.push @_hgInstance.areasOnMap     if @_hgInstance.areasOnMap?
      areaViewer.push @_hgInstance.areasOnGlobe   if @_hgInstance.areasOnGlobe?

      ### INIT AREAS ###
      @_areaLoader = new HG.AreaLoader @_hgInstance
      areas = @_areaLoader.loadInit()

      @_areaLoader.onFinishLoading @, (area) ->
        @_createGeometry area
        @_createName area if area.hasName()
        @_activate area


      ### TO INTERFACE ###

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
              @_focus area

          # normal mode: each area can be hovered
          else  # @_areaEditMode is off
            @_focus area


        # ----------------------------------------------------------------------
        # unhover areas => unfocus!
        view.onUnfocusArea @, (area) ->
          @_unfocus area


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
              @_deselect area

            # area is deselected => toggle currently selected area <-> new selection
            else  # not area.isSelected()
              @_deselect @_selectedAreas[0] if @_selectedAreas.length is 1
              @_select area


          # multi-selection mode: add to selected area until max limit is reached
          else  # @_maxSelections > 1

            # area is selected => deselect
            if area.isSelected()
              @_deselect area

            # area is not selected and maximum number of selections not reached => select it
            else if @_selectedAreas.length < @_maxSelections
              @_select area

            # else: area not selected but selection limit reached => no selection

          @_DEBUG_OUTPUT 'select area (from view)' if DEBUG


      # ========================================================================
      ## listen to Edit Mode

      # ========================================================================
      # swap single-selection <-> multi-selection mode
      # swap normal mode <-> edit mode

      # ------------------------------------------------------------------------
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


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onEnableAreaEditMode @, () ->

        @_areaEditMode = on
        @_maxSelections = HGConfig.max_area_selection.val

        # if there has been an area already selected in single-selection mode
        # it will still be in the @_selectedAreas array and can stay there,
        # since it will never be deselected

        @_DEBUG_OUTPUT 'start edit mode' if DEBUG


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDisableAreaEditMode @, (selectedAreaId=null) ->
        @_DEBUG_OUTPUT 'end edit mode (before)' if DEBUG

        @_areaEditMode = off
        @_maxSelections = 1

        # deselect each area
        # -> except for the one specified by edit mode to be kept selected
        @_cleanSelectedAreas selectedAreaId
        @_cleanEditAreas()

        @_DEBUG_OUTPUT 'end edit mode (after)' if DEBUG


      # ========================================================================
      # handle new, updated and old areas

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onCreateArea @, (id, geometry, shortName=null, formalName=null) ->

        # error handling: new area must have valid id and geometry
        return if (not id) or (not geometry.isValid())

        # TODO: überarbeiten
        area = new HG.Area id, geometry, shortName, formalName,

        @_createGeometry area
        @_createName area if area.hasName()
        @_activate area
        @_startEdit area

        @_DEBUG_OUTPUT 'create area' if DEBUG


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onUpdateAreaGeometry @, (id, newGeometry) ->
        area = @getArea id

        ## comparison variables
        hadGeometryBefore = area?.hasGeometry()
        hasGeometryNow = newGeometry.isValid() is true

        ## update status of area

        # if there was no geometry before and there is a valid new geometry now
        # => create it
        if (not hadGeometryBefore) and (hasGeometryNow)

          # TODO: überarbeiten
          area = new HG.Area id, newGeometry

          @_createGeometry area
          @_activate area
          @_startEdit area, no
          @_select area, yes

        # if there was a geometry before and there is a valid new geometry now
        # => update it
        else if (hadGeometryBefore) and (hasGeometryNow)
          @_updateGeometry area, newGeometry
          @_updateRepresentativePoint area, null  if area.hasName()

        # if there was a geometry before and there is no valid new geometry now
        # => remove it
        else if (hadGeometryBefore) and (not hasGeometryNow)
          @_deselect area, no
          @_endEdit area, no
          @_unfocus area, no
          @_deactivate area
          @_removeGeometry area
          @_removeName area if area.hasName()

        # else if there was no geometry before and there is not valid new geometry now
        # => no need to change something

        @_DEBUG_OUTPUT 'update area geometry' if DEBUG


      # ------------------------------------------------------------------------
      # name and position come always together from edit mode, so both properties
      # can exceptionally be treated in the same function
      @_hgInstance.editMode.onUpdateAreaName @, (id, newShortName=null, newFormalName=null, newPosition=null) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        ## update model
        hadNameBefore = area.hasName()
        hasNameNow = newShortName isnt null

        ## update area status

        # if there was no name before and there is a valid new name now
        # => create it
        if (not hadNameBefore) and (hasNameNow)
          @_createName area, newShortName, newFormalName
          @_updateRepresentativePoint area, newPosition if newPosition

        # if there was a name before and there is a valid new name now
        # => update it
        else if (hadNameBefore) and (hasNameNow)
          @_updateName area, newShortName, newFormalName
          @_updateRepresentativePoint area, newPosition if newPosition

        # if there was a name before and there is no valid new name now
        # => remove it
        else if (hadNameBefore) and (not hasNameNow)
          @_removeName area


        # else: if there was no name before and there is not valid new name now
        # => no need to change something


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onStartEditArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        @_startEdit area

        @_DEBUG_OUTPUT 'start edit mode' if DEBUG


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onEndEditArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        @_endEdit area

        @_DEBUG_OUTPUT 'end edit mode' if DEBUG


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onSelectArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        @_select area

        @_DEBUG_OUTPUT 'select area' if DEBUG


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDeselectArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        @_deselect area

        @_DEBUG_OUTPUT 'deselect area' if DEBUG


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onRemoveArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found
        return if (not area)

        @_endEdit area, no
        @_unfocus area, no
        @_deselect area, no
        @_deactivate area
        @_removeGeometry area
        @_removeName area if area.hasName()

        @_DEBUG_OUTPUT 'remove area' if DEBUG


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

  # ============================================================================
  _createGeometry: (area, geometry=null) ->
    area.setGeometry geometry if geometry                       # model
    @notifyAll 'onCreateGeometry', area                         # view

  # ----------------------------------------------------------------------------
  _updateGeometry: (area, geometry) ->
    area.setGeometry geometry                                   # model
    @notifyAll 'onUpdateGeometry', area                         # view

  # ----------------------------------------------------------------------------
  _removeGeometry: (area) ->
    area.setGeometry new HG.Point null # empty geometry         # model
    @notifyAll 'onRemoveGeometry', area                         # view

  # ============================================================================
  _createName: (area, shortName=null, formalName=null) ->
    area.setShortName shortName if shortName                    # model
    area.setFormalName formalName if formalName                 # model
    @notifyAll 'onCreateName', area                             # view

  # ----------------------------------------------------------------------------
  _updateName: (area, shortName, formalName) ->
    area.setShortName shortName                                 # model
    area.setFormalName formalName                               # model
    @notifyAll 'onUpdateName', area                             # view

  # ----------------------------------------------------------------------------
  _updateRepresentativePoint: (area, point=null) ->
    if point
      area.setRepresentativePoint point                         # model
    else
      area.resetRepresentativePoint()                           # model
    @notifyAll 'onUpdateRepresentativePoint', area              # view

  # ----------------------------------------------------------------------------
  _removeName: (area) ->
    area.removeName()                                           # model
    @notifyAll 'onRemoveName', area                             # view

  # ============================================================================
  _activate: (area) ->
    if not area.isActive()
      area.activate()                                           # model
      @_activeAreas.push area                                   # controller

  # ----------------------------------------------------------------------------
  _deactivate: (area) ->
    if area.isActive()
      area.deactivate()                                         # model
      @_activeAreas.splice((@_activeAreas.indexOf area), 1)     # controller

  # ============================================================================
  _select: (area, updateView=yes) ->
    if not area.isSelected()
      area.select()                                             # model
      @_selectedAreas.push area                                 # controller
      @notifyAll 'onUpdateStatus', area if updateView           # view
      @notifyAll 'onSelect', area       if updateView           # view

  # ----------------------------------------------------------------------------
  _deselect: (area, updateView=yes) ->
    if area.isSelected()
      area.deselect()                                           # model
      @_selectedAreas.splice((@_selectedAreas.indexOf area), 1) # controller
      @notifyAll 'onUpdateStatus', area if updateView           # view
      @notifyAll 'onDeselect', area     if updateView           # view

  # ============================================================================
  _focus: (area, updateView=yes) ->
    area.focus()                                                # model
    @notifyAll 'onUpdateStatus', area if updateView             # view

  # ----------------------------------------------------------------------------
  _unfocus: (area, updateView=yes) ->
    area.unfocus()                                              # model
    @notifyAll 'onUpdateStatus', area if updateView             # view

  # ============================================================================
  _startEdit: (area, updateView=yes) ->
    if not area.isInEdit()
      area.inEdit yes                                           # model
      @_editAreas.push area                                     # controller
      @notifyAll 'onUpdateStatus', area if updateView           # view

  # ----------------------------------------------------------------------------
  _endEdit: (area, updateView=yes) ->
    if area.isInEdit()
      area.inEdit no                                            # model
      @_editAreas.splice((@_editAreas.indexOf area), 1)         # controller
      @notifyAll 'onUpdateStatus', area if updateView           # view



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
      area.deselect()                                           # model
      @_selectedAreas.splice(loopIdx, 1)                        # controller
      @notifyAll 'onUpdateStatus', area                         # view
      @notifyAll 'onDeselect', area                             # view

      loopIdx--

  # ----------------------------------------------------------------------------
  _cleanEditAreas: () ->
    # manuel while loop, because selected areas shrinks while operating in it
    loopIdx = @_editAreas.length-1
    while loopIdx >= 0

      area = @_editAreas[loopIdx]

      area.inEdit no                                            # model
      @_editAreas.splice(loopIdx, 1)                            # controller
      @notifyAll 'onUpdateStatus', area                        # view

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
