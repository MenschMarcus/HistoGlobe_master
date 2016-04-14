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

    @addCallback 'onCreateArea'


    # handle config
    defaultConfig = {}

    @_config = $.extend {}, defaultConfig, config


    # init members
    @_areaHandles = []            # all areas in HistoGlobe ((in)visible, (un)selected, ...)
    @_changeQueue = new Queue()   # queue for all area changes on the map/globe

    @_maxSelections = 1           # 1 = single-selection mode, n = multi-selection mode



    ############################################################################
    # TRASHCAN

    # to AreaHandle?
    @_visibleAreas = []            # set of all HG.AreaHandle's currently visible
    @_selectedAreas = []          # array of all currently visible areas
    @_invisibleAreas = []          # set of all HG.AreaHandle's currently invisible


    # @_hgInstance.editMode.onCreateArea @, (id, geometry) ->
    # @_hgInstance.editMode.onUpdateAreaGeometry @, (id, geometry) ->
    # @_hgInstance.editMode.onUpdateAreaRepresentativePoint @, (id, reprPoint=null) ->
    # @_hgInstance.editMode.onAddAreaName @, (id, shortName, formalName) ->
    # @_hgInstance.editMode.onUpdateAreaName @, (id, shortName, formalName) ->
    # @_hgInstance.editMode.onRemoveAreaName @, (id) ->
    # @_hgInstance.editMode.onRemoveArea @, (id) ->
    # @_hgInstance.editMode.onShowArea @, (id) ->
    # @_hgInstance.editMode.onHideArea @, (id) ->
    # @_hgInstance.editMode.onStartEditArea @, (id) ->
    # @_hgInstance.editMode.onEndEditArea @, (id) ->
    # @_hgInstance.editMode.onSelectArea @, (id) ->
    # @_hgInstance.editMode.onDeselectArea @, (id) ->

    ############################################################################




  # ============================================================================
  hgInit: (@_hgInstance) ->
    # add module to HG instance
    @_hgInstance.areaController = @


    ### INTERACTION ###

    @_hgInstance.onAllModulesLoaded @, () =>

      ### INTERFACE: HIVENT CONTROLLER ###

      # ========================================================================
      # receive a new set of area changes and prepare it to add to the change
      # queue to eventually execute it
      # ========================================================================

      @_hgInstance.hiventController.onChangeAreas @, (changes, changeDir, timeLeap) ->

        for change in changes

          # prepare change
          newChange = {
            timestamp         : moment()    # timestamp at wich changes shall be executed
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
            newChange.timestamp.add HGConfig.slow_animation_time.val, 'milliseconds'

          # set old / new areas to toggle
          # changeDir = +1 => timeline moves forward => old areas are old areas
          # else      = -1 => timeline moves backward => old areas are new areas
          tempOldAreas = []
          tempNewAreas = []

          for area in change.oldAreas
            if changeDir is 1 then tempOldAreas.push area else tempNewAreas.push area

          for area in change.newAreas
            if changeDir is 1 then tempNewAreas.push area else tempOldAreas.push area

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


  # ============================================================================
    # infinite loop that executes all changes in the queue
    # find next ready area change and execute it (one at a time)
    mainLoop = setInterval () =>    # => is important to be able to access global variables (compared to ->)

      # execute change if it is ready
      while not @_changeQueue.isEmpty()

        # check if first element in queue is ready (timestamp is reached)
        break if @_changeQueue.peek().timestamp > moment()

        # get next change
        change = @_changeQueue.dequeue()

        # show / hide the new / old area
        areaHandle.show() for areaHandle in change.newAreas
        areaHandle.hide() for areaHandle in change.oldAreas

        # fade-out transition area
        # if change.transitionArea
        #   @notifyAll "onFadeOutArea", @_getTransitionById change.transitionArea

        # fade-out transition border
        # if change.transitionBorder
        #   @notifyAll "onFadeOutBorder", @_getTransitionById change.transitionBorder

    , HGConfig.change_queue_interval.val


  # ============================================================================
  # Receive a new AreaHandle (from EditMode and DatabaseInterface) and add it to
  # the list and tell the view about it
  # ============================================================================

  addAreaHandle: (areaHandle) ->
    @_areaHandles.push areaHandle
    @notifyAll 'onCreateArea', areaHandle

    # listen to destruction callback and tell everybody about it
    areaHandle.onDestroy @, () =>
      @_areaHandles.splice(@_areaHandles.indexOf(areaHandle), 1)

    @_DEBUG_OUTPUT 'CREATE AREA'


  # ============================================================================
  # set / get Single- and Multi-Selection Mode
  # -> how many areas can be selected at the same time?
  # ============================================================================

  enableMultiSelection: (num) ->

    # error handling: must be a number and can not be smaller than 1
    if (num < 1) or (isNaN num)
      return console.error "There can not be less than 1 area selected"

    # set maximum number of selections
    @_maxSelections = num

    # if there has been an area already selected in single-selection mode
    # it will still be in the @_selectedAreas array and can stay there,
    # since it will never be deselected

    @_DEBUG_OUTPUT 'ENABLE MULTI SELECTION'


  # ------------------------------------------------------------------------
  disableMultiSelection: () ->

    # restore single-selection mode
    @_maxSelections = 1

    # is it necessary to clean the selected areas or should that be the
    # task of the edit mode?
    # areaHandle.deselect() for areaHandle in @_areaHandles

    @_DEBUG_OUTPUT 'DISABLE MULTI SELECTION'


  # ------------------------------------------------------------------------
  getMaxNumOfSelections: () -> @_maxSelections


  # ============================================================================
  # GETTER for areas
  # ============================================================================

  getAreaHandle: (id) ->
    for areaHandle in @_areaHandles
      area = areaHandle.getArea()
      if area.id is id
        return areaHandle
    return null

  # ----------------------------------------------------------------------------
  getAreaHandles: () ->
    @_areaHandles



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _DEBUG_OUTPUT: (id) ->

    return if not DEBUG

    sel = []
    sel.push a.getId() + " (" + a.getShortName() + ")" for a in @_selectedAreas
    edi = []
    edi.push a.getId() + " (" + a.getShortName() + ")" for a in @_editAreas

    console.log id
    console.log "areas (act+inact=all): ", @_visibleAreas.length, "+", @_invisibleAreas.length, "=", @_visibleAreas.length + @_invisibleAreas.length
    console.log "max selections + areas:", @_maxSelections, ":", sel.join(', ')
    console.log "areas (act+inact=all): ", @_activeAreas.length, "+", @_inactiveAreas.length, "=", @_activeAreas.length + @_inactiveAreas.length
    console.log "=============================================================="
