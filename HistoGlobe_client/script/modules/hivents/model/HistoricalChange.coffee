window.HG ?= {}

# ==============================================================================
# MODEL
# HistoricalChange defines what has historically changed because of an Hivent.
# DTO => no functionality
#
# operations:
#   CRE) creation of new area:                         -> A
#   UNI) unification of many to one area:         A, B -> C
#   INC) incorporation of many into one area:     A, B -> A
#   SEP) separation of one into many areas:       A -> B, C
#   SEC) secession of many areas from one:        A -> A, B
#   NCH) name change of one or many areas:        A -> A', B -> B'
#   TCH) territory change of one or many areas:   A -> A', B -> B'
#   DES) destruction of an area:                  A ->
# ==============================================================================


class HG.HistoricalChange

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  constructor: (data)  ->
    @id             = data.id
    @operation      = data.operation
    @hivent         = data.hivent       # HG.Hivent
    @areaChanges    = []                # HG.AreaChange


  # ============================================================================
  # execute the change: visualize areas of interest and
  # then execute all its associated AreaChanges
  # ============================================================================

  execute: (direction, timeLeap) ->
    # +1: execute change forward
    # -1: execute change backward

    # TODO: visualize transition if user has not scrolled too far
    if timeLeap < HGConfig.time_leap_threshold.val

      switch @operation

        when 'CRE'
          # fade in new border
          # fade in new name
          @_executeAreaChanges direction

        when 'UNI'
          # fade out common border
          # fade out old names
          @_executeAreaChanges direction
          # fade in new name

        when 'INC'
          # fade out common border
          # fade out old name
          @_executeAreaChanges direction
          # move existing name

        when 'SEP'
          # fade in common border
          # fade in new names
          @_executeAreaChanges direction
          # fade out old name

        when 'SEC'
          # fade in common border
          # fade in new name
          @_executeAreaChanges direction
          # move existing name

        when 'NCH'
          # fade out old name
          @_executeAreaChanges direction
          # fade in new name

        when 'TCH'
          # fade in transition borders
          @_executeAreaChanges direction
          # fade out transition borders

        when 'DES'
          @_executeAreaChanges direction
          # fade out old border
          # fade out old name

    else
      @_executeAreaChanges direction



  # ============================================================================
  # execute all its associated AreaChanges
  # ============================================================================

  _executeAreaChanges: (direction) ->
    # execute all its changes
    for areaChange in @areaChanges
      areaChange.execute direction



'''   ####################### TRASHCAN #####################

  ### ChangeQueue ###

  @_changeQueue = new Queue()   # queue for all area changes on the map/globe
  @_changeQueue.enqueue newChange

  # ============================================================================
  # infinite loop that executes all changes in the queue
  # find next ready area change and execute it (one at a time)
  # ============================================================================

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


  ### Remove Duplicates ###

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

'''