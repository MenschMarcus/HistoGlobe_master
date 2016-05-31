window.HG ?= {}

# ==============================================================================
# HiventController is used to load Hivent data from files and store them into
# buffers. Additionally, this class provides functionality to filter and access
# Hivents.
#
# TODO: use doubly-linked list for @_hiventHandles to not iterate through whole
# array all the time.
# ==============================================================================


class HG.HiventController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # Constructor
  # Initializes members and stores the given configuration named "config".
  # ============================================================================
  constructor: (config) ->

    ## init callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onHiventAdded'


    ## init config
    defaultConfig =
      dsvConfigs: undefined
      numHiventsInView: 10

    @_config = $.extend {}, defaultConfig, config


    ## init member variables
    @_hiventHandles     = new HG.DoublyLinkedList

    @_lastHandleNode  = null  # reference pointer to the historically last handle

    @_nowDate = null          # copy of the current date


  # ============================================================================
  # Issues configuration depending on the current HistoGlobe instance.
  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add module to HistoGlobe instance
    @_hgInstance.hiventController = @


    ### INTERACTION ###

    @_hgInstance.onAllModulesLoaded @, () =>


      ### INITIALIZE ###

      # load initial Hivents on load from DatabaseInterface
      @_hgInstance.databaseInterface.onFinishLoadingInitData @, () ->

        # get inital NowDate
        @_nowDate = @_hgInstance.timeController.getNowDate()

        ## create current state on the map
        # -> accumulate all changes from the earliest hivent until now

        # start with first element
        currNode = @_hiventHandles.head.next

        # check for each hiventHandle (until the tail of the list is reached)
        while not currNode.isTail()

          currHandle = currNode.data

          # find the first Hivent later than the NowDate
          # => break, because we do not want to execute the change for this Hivent
          break if currHandle.getHivent().date > @_nowDate

          # execute operations associated to the Hivent
          currHandle.executeOperations 1 # forward!

          # set reference pointers
          @_lastHandleNode = currNode

          # check next node
          currNode = currNode.next


      ### VIEW ###

      ## load hivents that have happened since last now change
      @_hgInstance.timeController.onNowChanged @, (nowDate) =>

        # error handling: ensure that initial function will be executed first
        return if not @_nowDate

        # get change dates
        oldDate = @_nowDate
        newDate = nowDate

        # change direction: forward (+1) or backward (-1)
        changeDir = if oldDate < newDate then +1 else -1

        # get distance user has scrolled
        timeLeap = Math.abs(oldDate.year() - newDate.year())


        ## forward => iteratively check for next hivent if it happened
        if changeDir is 1

          currNode = @_lastHandleNode.next

          while not currNode.isTail()
            currHandle = currNode.data

            # if hivent has happened => execute changes and reset reference pointers
            if currHandle.happenedBetween oldDate, newDate
              currHandle.executeOperations changeDir
              @_lastHandleNode = currNode

              # check for next node
              currNode = currNode.next

            # if hivent has not happened => break the loop
            else break


        ## backward => iteratively check for next hivent if it happened
        else # changeDir is -1

          currNode = @_lastHandleNode

          while not currNode.isHead()
            currHandle = currNode.data

            # if hivent has happened => execute changes and reset reference pointers
            if currHandle.happenedBetween newDate, oldDate # N.B. swap old and new Date !!!
              currHandle.executeOperations changeDir
              @_lastHandleNode = currNode.prev

              # check for previous node
              currNode = currNode.prev

            # if hivent has not happened => break the loop
            else break


        # update now Date
        @_nowDate = nowDate


  # ============================================================================
  # Adds a created HiventHandle to the Doubly-Linked List at its chronologically
  # correct position
  # ============================================================================

  addHiventHandle: (hiventHandle) ->

    # in case of empty list, put it as first element
    if @_hiventHandles.isEmpty()
      @_hiventHandles.addFront hiventHandle

    # otherwise find its position in hiventHandleList
    else

      # start with first element
      currNode = @_hiventHandles.head.next

      # check for each hiventHandle (until the tail of the list is reached)
      while not currNode.isTail()

        currHandle = currNode.data

        # find the first Hivent with an earlier date
        # => break, because this node is the one we want to add the handle after
        break if hiventHandle.getHivent().date < currHandle.getHivent().date

        # check next node
        currNode = currNode.next


      # insert node into hiventHandle list and store node
      node = @_hiventHandles.addBefore hiventHandle, currNode

      # store node in the handle
      hiventHandle.handleListNode = node


    # if handle is destroyed
    hiventHandle.onDestroy @, () =>

      # remove it from the list
      @_hiventHandles.removeNode hiventHandle.handleListNode

      # and remove link to node in handle
      hiventHandle.handleListNode = null


  # ============================================================================
  # Returns all stored HiventHandles.
  # Additionally, if "object" and "callbackFunc" are specified, "callbackFunc"
  # is registered to be called for every Hivent loaded in the future and called
  # for every Hivent that has been loaded already.
  # ============================================================================

  getHivents: (object, callbackFunc) ->
    hiventHandles = []

    currNode = @_hiventHandles.head.next
    while not currNode.isTail()
      handle = currNode.data

      hiventHandles.push handle

      if object? and callbackFunc?
        @notify "onHiventAdded", object, handle

      currNode = currNode.next

    hiventHandles


  # ============================================================================
  # Returns a HiventHandle by the specified "hiventId". Every Hivent has to be
  # assigned a unique ID to avoid unexpected behaviour.
  # ============================================================================

  getHiventHandle: (hiventId) ->
    currNode = @_hiventHandles.head.next
    while not currNode.isTail()
      handle = currNode.data
      return handle if handle.getHivent().id is hiventId
      currNode = currNode.next

    console.log "A Hivent with the id \"#{hiventId}\" does not exist!"
    return null


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  # find Hivents happening between two dates and execute their changes
  # ============================================================================

  _executeOperations: (oldDate, newDate) ->

      # change direction: forward (+1) or backward (-1)
      changeDir = if oldDate < newDate then +1 else -1

      # opposite direction: swap old and new date, so it can be assumed that always oldDate < newDate
      if changeDir is -1
        tempDate = oldDate
        oldDate = newDate
        newDate = tempDate

      # distance user has scrolled
      timeLeap = Math.abs(oldDate.year() - newDate.year())

      # go through all changes in (reversed) order
      # check if the change date is inside the change range from the old to the new date
      # as soon as one change is inside, all changes will be executed until one change is outside the range
      # -> then termination of the loop
      inChangeRange = no
      changes = []

      # IMP!!! if change direction is the other way, also the hivents have
      # to be looped through the other way!
      for hiventHandle in @_hiventHandles by changeDir

        if hiventHandle.happenedBetween oldDate, newDate

          # state that a change is found => entered change range of hivents
          inChangeRange = yes

          # TODO: make nicer later
          for editOperation in hiventHandle.getHivent().editOperations
            editOperation.execute changeDir, timeLeap

        # N.B: if everything is screwed up: comment the following three lines ;)
        else
          # loop went out of change range => no hivent will be following
          break if inChangeRange