
window.HG ?= {}

# ==============================================================================
# MODEL
# EditOperation defines what has historically changed because of an Hivent.
# relates to one EditOperation
# DTO => no functionality
#
# EditOperations:
#   CRE) Create
#   MRG) Merge
#   DIS) Dissolve
#   CHB) Change Borders
#   REN) Rename
#   CES) Cease
# ==============================================================================


class HG.EditOperation

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  constructor: (data)  ->

    @id               = data.id

    # superordinate: Hivent
    @hivent           = null    # HG.Hivent

    # properties
    @operation        = data.operation  # 'XXX' of the list above

    # subordinate: HiventOperations
    @hiventOperations = []      # HG.HiventOperation


  # ============================================================================
  # get a textual description of what happened in the Change
  # ============================================================================

  getDescription: () ->

    # TODO: work with new operations

    # get short names of all old and new areas
    oldAreaNames = []
    newAreaNames = []
    tchAreaNames = []
    nchAreaNames = []
    for change in @hiventOperations
      switch change.operation
        when 'ADD' then newAreaNames.push change.newAreaName.shortName
        when 'DEL' then oldAreaNames.push change.oldAreaName.shortName
        when 'TCH' then tchAreaNames.push change.area.name.shortName
        when 'NCH'
          nchAreaNames.push change.oldAreaName.shortName
          nchAreaNames.push change.newAreaName.shortName

    # concatenate names together by ',' but the last one by 'and'
    oldStr = @_joinToEnum oldAreaNames
    newStr = @_joinToEnum newAreaNames
    tchStr = @_joinToEnum tchAreaNames
    nchStr = @_joinToEnum nchAreaNames, "to"

    switch @operation
      when 'CRE' then return "Create " + newStr
      when 'MRG' then return "Merge " + oldStr + " to " + tchStr
      when 'DIS' then return "Dissolve " + oldStr + " intoto " + newStr
      when 'CHB' then return "Change Border between " + tchStr
      when 'REN' then return "Rename " + nchStr
      when 'CES' then return "Cease " + oldStr


  # ============================================================================
  # execute the change: visualize areas of interest and
  # then execute all its associated HiventOperations
  # ============================================================================

  execute: (direction, timeLeap) ->
    # +1: execute change forward
    # -1: execute change backward

    for hiventOperation in @hiventOperations
      hiventOperation.execute direction

    # TODO: visualize transition if user has not scrolled too far
    # if timeLeap < HGConfig.time_leap_threshold.val


  # ============================================================================
  # join with a keyword as the separator between the last two elements
  # ============================================================================

  _joinToEnum: (array, separatorBetweenLastTwoElements='and') ->
    [
      array.slice(0, -1).join(', ')
      array.slice(-1)[0]
    ].join if array.length < 2 then '' else ' ' + separatorBetweenLastTwoElements + ' '



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