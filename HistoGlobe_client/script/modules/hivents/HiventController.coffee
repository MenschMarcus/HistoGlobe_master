window.HG ?= {}

# ==============================================================================
# HiventController is used to load Hivent data from files and store them into
# buffers. Additionally, this class provides functionality to filter and access
# Hivents.
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

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onHiventAdded"

    @_hiventHandles           = []
    @_handlesNeedSorting      = false

    @_currentTimeFilter       = null  # {start: <Date>, end: <Date>}
    @_currentSpaceFilter      = null  # { min: {lat: <float>, long: <float>},
                                      #   max: {lat: <float>, long: <float>}}
    @_currentCategoryFilter   = null  # [category_a, category_b, ...]
    @_categoryFilter          = null

    defaultConfig =
      dsvConfigs: undefined
      numHiventsInView: 10

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  # Issues configuration depending on the current HistoGlobe instance.
  # ============================================================================
  hgInit: (hgInstance) ->
    @_hgInstance = hgInstance

    # init AB tests
    @_ab = hgInstance.abTest.config

    # Register HiventController at the current HistoGlobe instance.
    @_hgInstance.hiventController = @

    # Register listeners to update filters or react on updated filters.
    @_hgInstance.timeline.onIntervalChanged @, (timeFilter) =>
      @setTimeFilter timeFilter

    @_hgInstance.categoryFilter?.onFilterChanged @,(categoryFilter) =>
      @_currentCategoryFilter = categoryFilter
      @_filterHivents()
    @_hgInstance.categoryFilter?.onPrefixFilterChanged @,(categoryFilter) =>
      @_currentCategoryFilter = categoryFilter
      @_filterHivents()

    @_categoryFilter = hgInstance.categoryFilter if hgInstance.categoryFilter

    # @loadHiventsFromJSON()
    @loadHiventsFromDSV()
    # @loadHiventsFromDatabase()

  # ============================================================================
  # Returns all stored HiventHandles.
  # Additionally, if "object" and "callbackFunc" are specified, "callbackFunc"
  # is registered to be called for every Hivent loaded in the future and called
  # for every Hivent that has been loaded already.
  # ============================================================================
  getHivents: (object, callbackFunc) ->
    if object? and callbackFunc?
      @onHiventAdded object, callbackFunc

      for handle in @_hiventHandles
        @notify "onHiventAdded", object, handle

    @_hiventHandles

  # ============================================================================
  # Sets the current time filter to the value of "timeFilter". The passed value
  # has to be an object of format {start: <Date>, end: <Date>}
  # ============================================================================
  setTimeFilter: (timeFilter) ->
    @_currentTimeFilter = timeFilter
    @_filterHivents();

  # ============================================================================
  # Sets the current space filter to the value of "spaceFilter". The passed
  # value has to be an object of format
  # { min: {lat: <float>, long: <float>},
  #   max: {lat: <float>, long: <float>}}
  # ===========================================================================
  setSpaceFilter: (spaceFilter) ->
    @_currentSpaceFilter = spaceFilter
    @_filterHivents()

  '''# ============================================================================
  setCategoryFilter: (categoryFilter) ->
    @_currentCategoryFilter = categoryFilter
    @_filterHivents()'''

  # ============================================================================
  # Returns a HiventHandle by the specified "hiventId". Every Hivent has to be
  # assigned a unique ID to avoid unexpected behaviour.
  # ============================================================================
  getHiventHandleById: (hiventId) ->
    for handle in @_hiventHandles
      if handle.getHivent().id is hiventId
        return handle
    console.log "A Hivent with the id \"#{hiventId}\" does not exist!"
    return null

  # ============================================================================
  # Returns a HiventHandle by the specified index of the internal array.
  # ============================================================================
  getHiventHandleByIndex: (handleIndex) ->
    return @_hiventHandles[handleIndex]

  # ============================================================================
  # Get the next HiventHandle.
  # Next in this case means the chronologically closest Hivent after the date
  # specified by the passed Date object "now". "ignoredIds" can be specified
  # to exclude specific HiventHandles from being selected.
  # ============================================================================
  getNextHiventHandle: (now, ignoredIds=[]) ->
    result = null
    distance = -1
    handles = @_hiventHandles
    handles= handles.concat(@_hgInstance.hiventGalleryWidget.getHiventHandles()) if @_hgInstance.hiventGalleryWidget

    for handle in handles
      if handle._state isnt 0 and not (handle.getHivent().id in ignoredIds)
        diff = handle.getHivent().startDate.getTime() - now.getTime()
        if (distance is -1 or diff < distance) and diff >= 0
          distance = diff
          result = handle
    return result

  # ============================================================================
  # Get the next HiventHandle.
  # Next in this case means the chronologically closest Hivent prior to the date
  # specified by the passed Date object "now". "ignoredIds" can be specified
  # to exclude specific HiventHandles from being selected.
  # ============================================================================
  getPreviousHiventHandle: (now, ignoredIds=[]) ->
    result = null
    distance = -1
    handles = @_hiventHandles
    handles= handles.concat(@_hgInstance.hiventGalleryWidget.getHiventHandles()) if @_hgInstance.hiventGalleryWidget

    for handle in handles
      if handle._state isnt 0 and not (handle.getHivent().id in ignoredIds)
        diff = now.getTime() - handle.getHivent().startDate.getTime()
        if (distance is -1 or diff < distance) and diff >= 0
          distance = diff
          result = handle
    return result

  ############################### INIT FUNCTIONS ###############################

  # ============================================================================
  # loadHiventsFromDatabase: (config) ->
  #   defaultConfig =
  #     hiventServerName: ""
  #     hiventDatabaseName: ""
  #     hiventTableName: ""
  #     multimediaServerName: ""
  #     multimediaDatabaseName: ""
  #     multimediaTableName: ""

  #   config = $.extend {}, defaultConfig, config

  #   dbInterface = new HG.HiventDatabaseInterface(config.hiventServerName, config.hiventDatabaseName)
  #   dbInterface.getHivents {
  #     tableName: config.hiventTableName,
  #     upperLimit: 100,
  #     success:
  #       (data) =>
  #         builder = new HG.HiventBuilder config
  #         rows = data.split "\n"
  #         for row in rows
  #           builder.constructHiventFromDBString row, (hivent) =>
  #             if hivent
  #               handle = new HG.HiventHandle hivent
  #               @_hiventHandles.push handle
  #               callback handle for callback in @_onHiventAddedCallbacks
  #               @_filterHivents()

  #   }

  # ============================================================================
  # loadHiventsFromJSON: (config) ->
  #   defaultConfig =
  #     hiventJSONPaths: []
  #     multimediaJSONPaths: []

  #   config = $.extend {}, defaultConfig, config

  #   for hiventJSONPath in config.hiventJSONPaths
  #     $.getJSON(hiventJSONPath, (hivents) =>
  #       builder = new HG.HiventBuilder config
  #       for h in hivents
  #         builder.constructHiventFromJSON h, (hivent) =>
  #           if hivent
  #             handle = new HG.HiventHandle hivent
  #             @_hiventHandles.push handle
  #             callback handle for callback in @_onHiventAddedCallbacks
  #             @_filterHivents()

  #     )

  # ============================================================================
  # Loads Hivent data from all delimiter seperated files specified in
  # HiventController's config. For each loaded Hivent, a HiventHandle is created
  # and pushed into the internal array @_hiventHandles.
  # ============================================================================
  loadHiventsFromDSV: () ->
    if @_config.dsvConfigs?

      # Loop over all files occuring in the configuration
      for dsvConfig in @_config.dsvConfigs
        defaultConfig =
          path: ""
          delimiter: "|"
          ignoredLines: [] # line indices starting at 1
          # indexMapping specifies at which column the respective attribute can
          # be found.
          indexMapping:
            id          : 0
            name        : 1
            description : 2
            startDate   : 3
            endDate     : 4
            displayDate : 5
            location    : 6
            lat         : 7
            long        : 8
            category    : 9
            multimedia  : 10
            # TODO: add link and region

        dsvConfig = $.extend {}, defaultConfig, dsvConfig

        # Configuration for parsing dsv files.
        parse_config =
          delimiter: dsvConfig.delimiter
          header: false

        # Auxiliary function to encapsulate loading from dsv files.
        buildHivent = (config) =>
          # ---------------------------------------------------
          # async: false bremst den Hivent Controller aus, bis die config.path (data) geladen sind
          $.ajaxSetup({
            async: false
          });
          # kann aber auch raus ... zur Not
          # ---------------------------------------------------

          # Asynchronously read the file.
          $.get config.path,
            (data) =>
              # If the file has been loaded successfully, parse it.
              parseResult = $.parse data, parse_config

              # HiventBuilder is started for each line containing Hivent data.
              builder = new HG.HiventBuilder config, @_hgInstance.multimediaController
              for result, i in parseResult.results
                unless i+1 in config.ignoredLines
                  builder.constructHiventFromArray result, (hivent) =>
                    if hivent
                      handle = new HG.HiventHandle hivent
                      @_hiventHandles.push handle
                      @notifyAll "onHiventAdded", handle
                      @_handlesNeedSorting = true

              @_filterHivents() # if in doubt, indent

        buildHivent dsvConfig

        @_currentCategoryFilter = @_categoryFilter.getCurrentFilter()


  # ============================================================================
  # Blends in all visible Hivents.
  # ============================================================================
  showVisibleHivents: ->
    for handle in @_hiventHandles

      state = handle._state

      if state isnt 0
        handle.setState 0
        handle.setState state


  ############################# MAIN FUNCTIONS #################################

  # ============================================================================
  # Filters all HiventHandles according to all current filters
  # ============================================================================
  _filterHivents: ->
    if @_handlesNeedSorting

      # filter by date
      @_hiventHandles.sort (a, b) =>
        if a? and b?
          unless a.getHivent().startDate.getTime() is b.getHivent().startDate.getTime()
            return a.getHivent().startDate.getTime() - b.getHivent().startDate.getTime()
          else
            if a.getHivent().id > b.getHivent().id
              return 1
            else if a.getHivent().id < b.getHivent().id
              return -1
        return 0

    for handle, i in @_hiventHandles
      if @_handlesNeedSorting
        handle.sortingIndex = i
      hivent = handle.getHivent()

      state = 1
      # 0 --> invisible
      # 1 --> visiblePast
      # 2 --> visibleFuture

      # filter by category
      if @_currentCategoryFilter?
        noCategoryFilter = @_currentCategoryFilter.length is 0
        defaultCategory = hivent.category is "default"
        inCategory = @areEqual hivent.category, @_currentCategoryFilter
        unless noCategoryFilter or defaultCategory or inCategory
          state = 0

      if state isnt 0 and @_currentTimeFilter?
        # start date in visible future
        if hivent.startDate.getTime() > @_currentTimeFilter.now.getTime() and hivent.startDate.getTime() < @_currentTimeFilter.end.getTime()
          #make them visible in future
          state = 1
        # completely  outside
        else if hivent.startDate.getTime() > @_currentTimeFilter.end.getTime() or hivent.endDate.getTime() < @_currentTimeFilter.start.getTime()
          state = 0

      # filter by location
      if state isnt 0 and @_currentSpaceFilter?
        unless hivent.lat >= @_currentSpaceFilter.min.lat and
               hivent.long >= @_currentSpaceFilter.min.long and
               hivent.lat <= @_currentSpaceFilter.max.lat and
               hivent.long <= @_currentSpaceFilter.max.long
          state = 0

      if @_ab.hiventsOnTl is "A"
        handle.setState state
      else if @_ab.hiventsOnTl is "B"
        handle._tmp_state = state

      if state isnt 0
        if @_currentTimeFilter?
          # half of timeline:
          #new_age = Math.min(1, (hivent.endDate.getTime() - @_currentTimeFilter.start.getTime()) / (@_currentTimeFilter.now.getTime() - @_currentTimeFilter.start.getTime()))
          # quarter of timeline:
          new_age = Math.min(1, ((hivent.endDate.getTime() - @_currentTimeFilter.start.getTime()) / (0.5*(@_currentTimeFilter.now.getTime() - @_currentTimeFilter.start.getTime())))-1)
          if new_age isnt handle._age
            handle.setAge new_age
    ###
    # importance filter: assign each hivent an importance score
    if @_ab.hiventsOnTl is "B"
      impScores = []
      for handle, i in @_hiventHandles

        # only for active hivents
        if handle._tmp_state > 0
          hivent = handle.getHivent()

          # 1) distance to now date
          nowTime = @_currentTimeFilter.now.getTime()
          hiventTime = (hivent.endDate.getTime() + hivent.startDate.getTime()) / 2
          nowDist = Math.abs(hiventTime - nowTime)

          # 2) importance category
          imp = hivent.isImp + 1

          # set importance and add in array
          impScore = nowDist * (1/imp)/2

          impScores.push
            handle: handle
            score:  impScore

      # sort hivents by importance score
      impScores.sort (a,b) =>
        return a.score - b.score

      # set hivents with lowest X imp scores to visible, the other to invisible
      for score, i in impScores
        # get current visible state
        state = score.handle._tmp_state

        # if hivent is not one of the most X important ones, set it to invisible
        if i >= @_config.numHiventsInView
          state = 0
        # else: take the given state

        # finally set the visible state and tell everyone
        score.handle.setState state

    ###
    @_handlesNeedSorting = false

  # ============================================================================
  areEqual: (str1, str2) ->
    (str1?="").localeCompare(str2) is 0
