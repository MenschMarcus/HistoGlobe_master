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


    # init members
    @_areas = []                  # set of all HG.Area's in the system
                                  # -> no area gets ever deleted from here
    @_activeAreas = []            # set of all HG.Area's currently active

    @_maxSelections = 1           # 1 = single-selection mode, n = multi-selection mode
    @_selectedAreas = []          # array of all currently active areas
    @_areaEditMode = off          # in edit mode normal areas can not be selected
    @_editAreas = []              # stores all areas that are currently in edit mode

    @_changeQueue = new Queue()   # queue for all area changes on the map/globe


  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add module to HG instance
    @_hgInstance.areaController = @


    ### INTERACTION ###
    @_hgInstance.onAllModulesLoaded @, () =>

      ### INIT AREAS ###
      @_areaLoader = new HG.AreaLoader

      # load active areas
      @_areaLoader.loadInit @_hgInstance

      @_areaLoader.onLoadInitArea @, (area) ->
        @_areas.push area
        @_createGeometry area
        @_createName area if area.hasName()
        @_activate area

      # load inactive areas in the background
      @_areaLoader.onFinishLoadingInitAreas @, () ->
        @_areaLoader.loadRest @_hgInstance
        @_areaLoader.onLoadRestArea @, (area) ->
          @_areas.push area


      ### VIEW ###

      ## listen to each viewer (have the same interface)
      ## -> start only with AreasOnMap

      # ----------------------------------------------------------------------
      # hover areas => focus?
      @_hgInstance.areasOnMap.onFocusArea @, (area) ->

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
      @_hgInstance.areasOnMap.onUnfocusArea @, (area) ->
        @_unfocus area


      # ----------------------------------------------------------------------
      # click area => (de)select
      @_hgInstance.areasOnMap.onSelectArea @, (area) ->

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

        @_DEBUG_OUTPUT 'select area (from view)'


      # ========================================================================
      ### HIVENT CONTROLLER ###

      ## perform area changes
      # ------------------------------------------------------------------------

      @_hgInstance.hiventController.onChangeAreas @, (changes, timeLeap) ->

        for change in changes

          # prepare change
          newChange = {
            timestamp   : null      # timestamp at wich changes shall be executed
            oldAreas    : []        # areas to be deleted
            newAreas    : []        # areas to be added
            transArea   : null      # regions to be faded out when change is done
            transBorder : null      # borders to be faded out when change is done
          }

          # are there anmated transitions?
          # fade-in transition area and border unless user scrolled too far
          hasTransition = no

          if timeLeap < HGConfig.time_leap_threshold.val

            # do special fading in/out for special operations
            if change.operation is 'ADD'
              magic = 42

            else if change.operation is 'UNI'
              magic = 42

            else if change.operation is 'SEP'
              magic = 42

            else if change.operation is 'CHB'
              magic = 42

            else if change.operation is 'CHN'
              magic = 42

            else if change.operation is 'DEL'
              magic = 42

            transArea = @_getTransitionById change.trans_area
            @notifyAll "onFadeInArea", transArea, yes
            hasTransition = yes

            transBorder = @_getTransitionById change.trans_border
            @notifyAll "onFadeInBorder", transBorder, yes
            hasTransition = yes


          # set timestamp
          ts = new Date()
          if hasTransition
            ts.setMilliseconds ts.getMilliseconds() + HGConfig.area_animation_time.val
          newChange.timestamp = ts

          # set old / new areas to toggle
          # changeDir = +1 => timeline moves forward => old areas are old areas
          # else      = -1 => timeline moves backward => old areas are new areas
          for area in change.newAreas
            if changeDir is 1 then newAreas.push area else oldAreas.push area

          for area in change.oldAreas
            if changeDir is 1 then oldAreas.push area else newAreas.push area

          # remove duplicates -> all areas/labels that are both in new or old array
          # TODO: O(n²) in the moment -> does that get better?
          iNew = 0
          iOld = 0
          lenNew = newAreas.length
          lenOld = oldAreas.length
          while iNew < lenNew
            while iOld < lenOld
              if newAreas[iNew] is oldAreas[iOld]
                newAreas[iNew] = null
                oldAreas[iOld] = null
                break # duplicates can only be found once => break here
              ++iOld
            ++iNew

          # remove nulls and assign to change array
          # TODO: make this nicer
          for area in oldAreas
            newChange.oldAreas.push area if area

          for area in newAreas
            newChange.newAreas.push area if area


          # finally enqueue distinct changes
          @_changeQueue.enqueue newChange



      # ========================================================================
      ### EDIT MODE ###

      ## toggle single-selection <-> multi-selection mode
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

        @_DEBUG_OUTPUT 'enable multi selection'

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDisableMultiSelection @, (selectedAreaId=null) ->

        # restore single-selection mode
        @_maxSelections = 1

        # deselect each area
        # -> except for the one specified by edit mode to be kept selected
        @_cleanSelectedAreas selectedAreaId

        @_DEBUG_OUTPUT 'disable multi selection'


      ## toggle normal mode <-> edit mode
      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onEnableAreaEditMode @, () ->

        @_areaEditMode = on
        @_maxSelections = HGConfig.max_area_selection.val

        # if there has been an area already selected in single-selection mode
        # it will still be in the @_selectedAreas array and can stay there,
        # since it will never be deselected

        @_DEBUG_OUTPUT 'start edit mode'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDisableAreaEditMode @, (selectedAreaId=null) ->
        @_DEBUG_OUTPUT 'end edit mode (before)'

        @_areaEditMode = off
        @_maxSelections = 1

        # deselect each area
        # -> except for the one specified by edit mode to be kept selected
        @_cleanSelectedAreas selectedAreaId
        @_cleanEditAreas()

        @_DEBUG_OUTPUT 'end edit mode (after)'


      ## handle new, updated and old areas

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onCreateArea @, (id, geometry, shortName=null, formalName=null) ->

        # error handling: new area must have valid id and geometry
        return if (not id) or (not geometry.isValid())

        area = new HG.Area {
          id:         id
          geometry:   geometry
          shortName:  shortName
          formalName: formalName
        }

        @_createGeometry area
        @_createName area if area.hasName()
        @_activate area
        @_startEdit area

        @_DEBUG_OUTPUT 'create area'


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
          area = new HG.Area {
            id:         id
            geometry:   newGeometry
          }

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

        @_DEBUG_OUTPUT 'update area geometry'


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

        @_DEBUG_OUTPUT 'start edit mode'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onEndEditArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        @_endEdit area

        @_DEBUG_OUTPUT 'end edit mode'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onSelectArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        @_select area

        @_DEBUG_OUTPUT 'select area'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDeselectArea @, (id) ->
        area = @getArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        @_deselect area

        @_DEBUG_OUTPUT 'deselect area'


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

        @_DEBUG_OUTPUT 'remove area'


  # ============================================================================
    # infinite loop that executes all changes in the queue
    mainLoop = setInterval () =>    # => is important to be able to access global variables (compared to ->)

      # find next ready area change and execute it (one at a time)

      # execute change if it is ready
      while not @_changeQueue.isEmpty()

        # check if first element in queue is ready (timestamp is reached)
        break if @_changeQueue.peek().timestamp > new Date()

        # get next change
        change = @_changeQueue.dequeue()

        # add all new areas
        # -> update the style before, so it has the correct style in the mmoment it is on the map
        if change.newAreas?
          for id in change.newAreas
            area = @_getAreaById id
            if area?
              area.setActive()
              @_updateAreaStyle area
              @notifyAll "onAddArea", area

        # remove all old areas
        # -> update the style before, so it has the correct style in the mmoment it is on the map
        if change.oldAreas?
          for id in change.oldAreas
            area = @_getAreaById id
            if area?
              area.setInactive()
              # @_updateAreaStyle area
              @notifyAll "onRemoveArea", area

        # add all new labels
        if change.newLabels?
          for id in change.newLabels
            label = @_getLabelById id
            if label?
              label.setActive()
              @_updateLabelStyle label
              @notifyAll "onAddLabel", label

        # remove all old labels
        if change.oldLabels?
          for id in change.oldLabels
            label = @_getLabelById id
            if label?
              label.setInactive()
              # @_updateLabelStyle label
              @notifyAll "onRemoveLabel", label

        # fade-out transition area
        if change.transArea?
          @notifyAll "onFadeOutArea", @_getTransitionById change.transArea

        # fade-out transition border
        if change.transBorder?
          @notifyAll "onFadeOutBorder", @_getTransitionById change.transBorder

        # update style changes
        if change.updateArea? and change.updateArea.isActive()
          @notifyAll "onUpdateAreaStyle", change.updateArea, @_isHighContrast

        if change.updateLabel? and change.updateLabel.isActive()
          @notifyAll "onUpdateLabelStyle", change.updateLabel, @_isHighContrast



    , 1000 # TODO: change back to 50



  # ============================================================================
  getActiveAreas: () ->     @_activeAreas
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

    return if not DEBUG

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
