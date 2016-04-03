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
    @_activeAreas = []            # set of all HG.Area's currently active
    @_inactiveAreas = []          # set of all HG.Area's currently inactive

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
      @_areaInterface = new HG.AreaInterface

      # 1. load all all areas from server
      # -> only with ids + info: active: yes/no, all together
      @_areaInterface.loadAllAreaIds @_hgInstance
      @_areaInterface.onFinishLoadingAreaIds @, (areas) ->
        for area in areas
          # update controller
          if area.isActive()
            @_activeAreas.push area
          else # area is inactive
            @_inactiveAreas.push area

        # 2. load all active areas from server
        # -> completely, in chunks
        @_areaInterface.loadActiveAreas @_hgInstance, @_activeAreas
        @_areaInterface.onLoadActiveArea @, (area) ->
          # update view
          @notifyAll 'onCreateGeometry', area
          @notifyAll 'onCreateName', area if area.hasName()

        # 3. load all inactive areas from server (when 2. is completely done)
        # -> completely, in chunks
        @_areaInterface.onFinishLoadingActiveAreas @, () ->
          @_areaInterface.loadInactiveAreas @_hgInstance, @_inactiveAreas
          # nothing to do on load, because everything is already there
          # model: updated in interface
          # controller: area only in @_activeAreas array s(step 1)
          # view: is inactive, so not to be shown
          # if needed later, the callbacks are:
          # @_areaInterface.onLoadInactiveArea @, (area) ->
          # @_areaInterface.onFinishLoadingInactiveAreas @, () ->


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
            # update model
            area.focus()
            # update view
            @notifyAll 'onUpdateStatus', area

        # normal mode: each area can be hovered
        else  # @_areaEditMode is off
          # update model
          area.focus()
          # update view
          @notifyAll 'onUpdateStatus', area


      # ----------------------------------------------------------------------
      # unhover areas => unfocus!
      @_hgInstance.areasOnMap.onUnfocusArea @, (area) ->
        # update model
        area.unfocus()
        # update view
        @notifyAll 'onUpdateStatus', area


      # ----------------------------------------------------------------------
      # click area => (de)select
      @_hgInstance.areasOnMap.onSelectArea @, (area) ->

        # area must be focussed in order for it to be selected
        # => no distinction between edit mode and normal mode necessary anymore
        return if not area.isFocused()

        # area is selected => deselect
        if area.isSelected()
          # update model
          area.deselect()
          # update controller
          @_selectedAreas.splice((@_selectedAreas.indexOf area), 1)
          # update view
          @notifyAll 'onUpdateStatus', area
          @notifyAll 'onDeselect', area


        # area is not selected => decide if it can be selected
        else

          # single-selection mode: toggle selected area
          if @_maxSelections is 1
            ## deselect currently selected area
            if @_selectedAreas.length is 1
              # update model
              @_selectedAreas[0].deselect()
              # update view
              @notifyAll 'onUpdateStatus', @_selectedAreas[0]
              @notifyAll 'onDeselect', @_selectedAreas[0]
              # update controller
              @_selectedAreas = []

            ## select newly selected area
            # update model
            area.select()
            # update controller
            @_selectedAreas.push area
            # update view
            @notifyAll 'onUpdateStatus', area
            @notifyAll 'onSelect', area


          # multi-selection mode: add to selected area until max limit is reached
          else  # @_maxSelections > 1

            # area is not selected and maximum number of selections not reached => select it
            if @_selectedAreas.length < @_maxSelections
              # update model
              area.select()
              # update controller
              @_selectedAreas.push area
              # update view
              @notifyAll 'onUpdateStatus', area
              @notifyAll 'onSelect', area

          # else: area not selected but selection limit reached => no selection

        @_DEBUG_OUTPUT 'select area (from view)'


      # ========================================================================
      ### HIVENT CONTROLLER ###

      ## perform area changes
      # ------------------------------------------------------------------------

      @_hgInstance.hiventController.onChangeAreas @, (changes, changeDir, timeLeap) ->

        for change in changes

          # prepare change
          newChange = {
            timestamp         : new Date()  # timestamp at wich changes shall be executed
            oldAreas          : []          # areas to be deleted
            newAreas          : []          # areas to be added
            transitionArea    : null        # regions to be faded out when change is done
            transitionBorder  : null        # borders to be faded out when change is done
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

            # transitionArea = @_getTransitionById change.trans_area
            # @notifyAll "onFadeInArea", transitionArea, yes
            # hasTransition = yes

            # transitionBorder = @_getTransitionById change.trans_border
            # @notifyAll "onFadeInBorder", transitionBorder, yes
            # hasTransition = yes

          # update timestamp
          if hasTransition
            newChange.timestamp.setMilliseconds newChange.timestamp.getMilliseconds() + HGConfig.area_animation_time.val

          # set old / new areas to toggle
          # changeDir = +1 => timeline moves forward => old areas are old areas
          # else      = -1 => timeline moves backward => old areas are new areas
          tempOldAreas = []
          tempNewAreas = []

          for area in change.newAreas
            if changeDir is 1 then tempNewAreas.push area else tempOldAreas.push area

          for area in change.oldAreas
            if changeDir is 1 then tempOldAreas.push area else tempNewAreas.push area

          # remove duplicates -> all areas/labels that are both in new or old array
          # TODO: O(n²) in the moment -> does that get better?
          itNew = 0
          itOld = 0
          lenNew = tempNewAreas.length
          lenOld = tempOldAreas.length
          while itNew < lenNew
            while itOld < lenOld
              if tempNewAreas[itNew] is tempOldAreas[itOld]
                tempNewAreas[itNew] = null
                tempOldAreas[itOld] = null
                break # duplicates can only be found once => break here
              ++itOld
            ++itNew

          # remove nulls and assign to change array
          # TODO: make this nicer
          newChange.oldAreas.push area for area in tempOldAreas
          newChange.newAreas.push area for area in tempNewAreas

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
      @_hgInstance.editMode.onCreateArea @, (id, geometry) ->

        # error handling: new area must have valid id and geometry
        return if (not id) or (not geometry.isValid())

        # update model
        area = new HG.Area id
        area.setGeometry geometry
        area.resetRepresentativePoint() # IMP!
        area.activate()
        area.select()
        area.inEdit yes

        # update view
        @notifyAll 'onCreateGeometry', area

        # update controller
        @_activeAreas.push area
        @_selectedAreas.push area
        @_editAreas.push area

        @_DEBUG_OUTPUT 'create area'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onUpdateAreaGeometry @, (id, geometry) ->
        area = @getActiveArea id

        # error handling: area must have had geometry before and geometry now
        return if (not area?) or (not area.hasGeometry()) or (not geometry.isValid())

        # update model
        area.setGeometry geometry

        # update view
        @notifyAll 'onUpdateGeometry', area

        @_DEBUG_OUTPUT 'update area geometry'

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onUpdateAreaRepresentativePoint @, (id, reprPoint=null) ->
        area = @getActiveArea id

        # error handling: area must have had geometry before and geometry now
        return if (not area?)

        # update model
        if reprPoint
          area.setRepresentativePoint reprPoint
        else
          area.resetRepresentativePoint()

        # update view
        @notifyAll 'onUpdateRepresentativePoint', area if area.hasName()

        @_DEBUG_OUTPUT 'update area geometry'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onAddAreaName @, (id, shortName, formalName) ->
        area = @getActiveArea id

        # error handling: area must be found and names must be given
        return if (not area?) or (not shortName) or (not formalName)

        # update model
        area.setShortName shortName
        area.setFormalName formalName

        # update view
        @notifyAll 'onCreateName', area

        @_DEBUG_OUTPUT 'create area name'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onUpdateAreaName @, (id, shortName, formalName) ->
        area = @getActiveArea id

        # error handling: area must have new name now
        return if (not area?) or (not area.hasName()) or (not shortName) or (not formalName)

        # update model
        area.setShortName shortName
        area.setFormalName formalName

        # update view
        @notifyAll 'onUpdateName', area

        @_DEBUG_OUTPUT 'update area name'

      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onRemoveAreaName @, (id) ->
        area = @getActiveArea id

        # error handling: area has to be found
        return if (not area)

        # update model
        area.removeName()

        # update view
        @notifyAll 'onRemoveName', area

        @_DEBUG_OUTPUT 'remove area name'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onRemoveArea @, (id) ->
        area = @getActiveArea id

        # error handling: area has to be found
        return if (not area)

        # no need to update model, because it will be deleted from all arrays,
        # so it does not appear anywhere and is therefore gone

        # update view
        @notifyAll 'onRemoveGeometry', area
        @notifyAll 'onRemoveName', area if area.hasName()

        # update controller
        idx = @_editAreas.indexOf area
        @_editAreas.splice idx, 1       if idx isnt -1
        idx = @_selectedAreas.indexOf area
        @_selectedAreas.splice idx, 1   if idx isnt -1
        idx = @_activeAreas.indexOf area
        @_activeAreas.splice idx, 1     if idx isnt -1
        idx = @_inactiveAreas.indexOf area
        @_inactiveAreas.splice idx, 1   if idx isnt -1

        @_DEBUG_OUTPUT 'remove area geometry'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onActivateArea @, (id) ->
        area = @getInactiveArea id

        # error handling: area has to be found and inactive
        return if (not area) or (area.isActive())

        # update model
        area.activate()

        # update view
        @notifyAll 'onCreateGeometry', area
        @notifyAll 'onCreateName', area if area.hasName()

        # update controller
        @_activeAreas.push area
        @_inactiveAreas.splice((@_inactiveAreas.indexOf area), 1)

        @_DEBUG_OUTPUT 'start edit mode'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDeactivateArea @, (id) ->
        area = @getActiveArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        # update model
        area.deactivate()

        # update view
        @notifyAll 'onRemoveName', area if area.hasName()
        @notifyAll 'onRemoveGeometry', area

        # update controller
        @_inactiveAreas.push area
        @_activeAreas.splice((@_activeAreas.indexOf area), 1)

        @_DEBUG_OUTPUT 'end edit mode'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onStartEditArea @, (id) ->
        area = @getActiveArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        if not area.isInEdit()
          # update model
          area.inEdit yes
          # update view
          @notifyAll 'onUpdateStatus', area
          # update controller
          @_editAreas.push area

        @_DEBUG_OUTPUT 'start edit mode'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onEndEditArea @, (id) ->
        area = @getActiveArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        if area.isInEdit()
          # update model
          area.inEdit no
          # update view
          @notifyAll 'onUpdateStatus', area
          # update controller
          @_editAreas.splice((@_editAreas.indexOf area), 1)

        @_DEBUG_OUTPUT 'end edit mode'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onSelectArea @, (id) ->
        area = @getActiveArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        if not area.isSelected()
          # update model
          area.select()
          # update controller
          @_selectedAreas.push area
          # update view
          @notifyAll 'onUpdateStatus', area
          @notifyAll 'onSelect', area

        @_DEBUG_OUTPUT 'select area'


      # ------------------------------------------------------------------------
      @_hgInstance.editMode.onDeselectArea @, (id) ->
        area = @getActiveArea id

        # error handling: area has to be found and active
        return if (not area) or (not area.isActive())

        if area.isSelected()
          # update model
          area.deselect()
          # update controller
          @_selectedAreas.splice (@_selectedAreas.indexOf area), 1
          # update view
          @notifyAll 'onUpdateStatus', area
          @notifyAll 'onDeselect', area

        @_DEBUG_OUTPUT 'deselect area'


  # ============================================================================
    # infinite loop that executes all changes in the queue
    # find next ready area change and execute it (one at a time)
    mainLoop = setInterval () =>    # => is important to be able to access global variables (compared to ->)

      # execute change if it is ready
      while not @_changeQueue.isEmpty()

        # check if first element in queue is ready (timestamp is reached)
        break if @_changeQueue.peek().timestamp > new Date()

        # get next change
        change = @_changeQueue.dequeue()

        # activate all new areas
        for id in change.newAreas
          area = @getInactiveArea id
          if area?
            # update model
            area.activate()
            # update view
            @notifyAll 'onCreateGeometry', area
            @notifyAll 'onCreateName', area if area.hasName()
            # update controller
            @_activeAreas.push area
            @_inactiveAreas.splice((@_inactiveAreas.indexOf area), 1)

        # deactivate all old areas
        for id in change.oldAreas
          area = @getActiveArea id
          if area?
            # update model
            area.deactivate()
            # update view
            @notifyAll 'onRemoveName', area if area.hasName()
            @notifyAll 'onRemoveGeometry', area
            # update controller
            @_inactiveAreas.push area
            @_activeAreas.splice((@_activeAreas.indexOf area), 1)

        # fade-out transition area
        # if change.transitionArea
        #   @notifyAll "onFadeOutArea", @_getTransitionById change.transitionArea

        # fade-out transition border
        # if change.transitionBorder
        #   @notifyAll "onFadeOutBorder", @_getTransitionById change.transitionBorder

    , HGConfig.change_queue_interval.val



  # ============================================================================
  getActiveAreas: () ->     @_activeAreas
  getSelectedAreas: () ->   @_selectedAreas

  # ----------------------------------------------------------------------------
  getArea: (id) ->
    area = @getActiveArea id
    area = @getInactiveArea id unless area
    area

  # ----------------------------------------------------------------------------
  getActiveArea: (id) ->
    for area in @_activeAreas
      if area.getId() is id
        return area
        break
    return null

  # ----------------------------------------------------------------------------
  getInactiveArea: (id) ->
    for area in @_inactiveAreas
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
      # update model
      area.deselect()
      # update controller
      @_selectedAreas.splice loopIdx, 1
      # update view
      @notifyAll 'onUpdateStatus', area
      # update view
      @notifyAll 'onDeselect', area

      loopIdx--

  # ----------------------------------------------------------------------------
  _cleanEditAreas: () ->
    # manual while loop, because selected areas shrinks while operating in it
    loopIdx = @_editAreas.length-1
    while loopIdx >= 0

      area = @_editAreas[loopIdx]

      # update model
      area.inEdit no
      # update controller
      @_editAreas.splice loopIdx, 1
      # update view
      @notifyAll 'onUpdateStatus', area

      loopIdx--


  # ============================================================================
  _DEBUG_OUTPUT: (id) ->

    return if not DEBUG

    sel = []
    sel.push a.getId() for a in @_selectedAreas
    edi = []
    edi.push a.getId() for a in @_editAreas

    console.log "-------------------------- ", id, "-------------------------- "
    console.log "max selections + areas:", @_maxSelections, ":", sel.join(', ')
    console.log "edit mode + areas      ", @_areaEditMode, ":", edi.join(', ')
    console.log "areas (act+inact=all): ", @_activeAreas.length, "+", @_inactiveAreas.length, "=", @_activeAreas.length + @_inactiveAreas.length,
    console.log "=============================================================="
