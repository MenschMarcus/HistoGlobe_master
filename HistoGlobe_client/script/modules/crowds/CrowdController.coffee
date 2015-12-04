window.HG ?= {}

class HG.CrowdController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    @_crowds = []
    @_filteredCrowds = []
    @_crowdsChanged = false
    @_onCrowdsChangedCallbacks = []
    @_nowDate = null
    @_numberOfSoldiers = 0

    @_currentTimeFilter = null

    defaultConfig =
      pathToCrowds: ""

    @_config = $.extend {}, defaultConfig, config

  # ============================================================================
  hgInit: (hgInstance) ->
    @_hgInstance = hgInstance

    @_hgInstance.crowdController = @

    @_nowDate = @_hgInstance.timeline.getNowDate()

    @_hgInstance.timeline.onNowChanged @, (date) =>
      @nowChanged date

    @_hgInstance.timeline.onIntervalChanged @, (timeFilter) =>
      @periodChanged timeFilter

    @_initCrowds()

    #@_updateCrowdSizes()

  # ============================================================================
  nowChanged: (date) ->
    @_nowDate = date
    for crowd in @_crowds
    	crowd.setDate @_nowDate
    @_filterCrowds()

  # ============================================================================
  periodChanged: (timeFilter) ->
  	@_currentTimeFilter = timeFilter

  	@_filterCrowds()

  # ============================================================================
  categoryChanged: (c) ->

  # ============================================================================
  getCrowds: -> @_crowds

  # ============================================================================
  onCrowdsChanged: (callbackFunc) ->
  	if callbackFunc and typeof(callbackFunc) == "function"
    	@_onCrowdsChangedCallbacks.push callbackFunc

  # ============================================================================
  setTimeFilter: (timeFilter) ->
    @_currentTimeFilter = timeFilter
    @_filterCrowds()

  # ============================================================================
  setSpaceFilter: (spaceFilter) ->
    @_currentSpaceFilter = spaceFilter
    @_filterCrowds()


  ############################### INIT FUNCTIONS ###############################

  # ============================================================================
  _initCrowds: () ->

    $.getJSON(@_config.pathToCrowds, (crowds) =>
      for c in crowds
        locations = []
        for l in c.locations
          locations.push L.latLng(l.lat,l.lng)
        times = []
        for t in c.times
          times.push new Date(t.year,t.month-1,t.day)
        sizes = []
        for s in c.sizes
          sizes.push s.size
        endDate = new Date(c.endDate.year,c.endDate.month-1,c.endDate.day)
        crowd = new HG.Crowd "#0087ff", c.nation, c.info, c.startLocation, locations, times, sizes, endDate, @_nowDate
        @_crowds.push crowd

      @_crowdsChanged = true
      @_filterCrowds()
      @_updateCrowdSizes()
      )

  # ============================================================================
  _getHighestTotalNumOfSoldiers: ->
    sum = 0
    for crowd in @_crowds
      maxSize = 0
      for size in crowd.getSizes()
        maxSize = size if size > maxSize
      sum += maxSize
    sum

  # ============================================================================
  _updateCrowdSizes: -> # percentages
    sum = @_getHighestTotalNumOfSoldiers()
    for crowd in @_crowds
      index = 0
      for size in crowd.getSizes()
        percentageSize = size / sum
        crowd.setPercentageSize index, percentageSize
        index++

  ############################# MAIN FUNCTIONS #################################

  # ============================================================================
  _filterCrowds: ->

  	for crowd in @_filteredCrowds
      crowd.destroy()
      crowd = null

    @_filteredCrowds = []

    for crowd in @_crowds
    	isInTime = false
    	unless @_currentTimeFilter == null
    		isInTime = not (crowd.getStartTime().getTime() > @_currentTimeFilter.end.getTime()) and
                   not (crowd.getEndTime().getTime() < @_currentTimeFilter.start.getTime())

      isInSpace = true
      ###unless @_currentSpaceFilter == null
        isInSpace = crowd.getLocation().lat >= @_currentSpaceFilter.min.lat and
                    crowd.getLocation().long >= @_currentSpaceFilter.min.long and
                    crowd.getLocation().lat <= @_currentSpaceFilter.max.lat and
                    crowd.getLocation().long <= @_currentSpaceFilter.max.long###

      if isInTime and isInSpace
      	@_filteredCrowds.push(crowd)

  	for callback in @_onCrowdsChangedCallbacks
      callback @_filteredCrowds

