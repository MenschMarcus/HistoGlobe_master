window.HG ?= {}

class HG.BattleController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    @_battles = []
    @_filteredBattles = []
    @_battlesChanged = false
    @_onBattlesChangedCallbacks = []
    @_nowDate = null

    @_currentTimeFilter = null

    defaultConfig =
      pathToBattles: ""

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (hgInstance) ->
    @_hgInstance = hgInstance

    @_hgInstance.battleController = @

    @_hgInstance.timeline.onNowChanged @, (date) =>
      @nowChanged date

    @_hgInstance.timeline.onIntervalChanged @, (timeFilter) =>
      @periodChanged timeFilter

    @_initBattles()

  # ============================================================================
  nowChanged: (date) ->
    @_nowDate = date
    for battle in @_battles
    	battle.setDate @_nowDate
    @_filterBattles()

  # ============================================================================
  periodChanged: (filter) ->
  	@_currentTimeFilter = filter

  	@_filterBattles()

  # ============================================================================
  categoryChanged: (c) ->

  # ============================================================================
  getBattles: -> @_battles

  # ============================================================================
  onBattlesChanged: (callbackFunc) ->
  	if callbackFunc and typeof(callbackFunc) == "function"
    	@_onBattlesChangedCallbacks.push callbackFunc

  # ============================================================================
  setTimeFilter: (timeFilter) ->
    @_currentTimeFilter = timeFilter
    @_filterBattles()

  # ============================================================================
  setSpaceFilter: (spaceFilter) ->
    @_currentSpaceFilter = spaceFilter
    @_filterBattles()


  ############################### INIT FUNCTIONS ###############################

  # ============================================================================
  _initBattles: () ->

    #battle1 = new HG.Battle "Schlacht um Verdun", new Date(1916,1,21), new Date(1916,11,20), L.latLng(49.1,5.23), [["Frankreich"],["Deutschland"]], "Frankreich", new Date(1914,3,4)
    #@_battles.push battle1

    #@_battlesChanged = true
    #@_filterBattles()

    $.getJSON(@_config.pathToBattles, (battles) =>
      for b in battles
        name = b.name
        startTime = new Date(b.start.year,b.start.month-1,b.start.day)
        endTime = new Date(b.end.year,b.end.month-1,b.end.day)
        location = L.latLng(b.location.lat, b.location.lng)
        combatants = []
        for c in b.combatants
          combatants.push c.country
        winner = []
        for w in b.winner
          winner.push w.country
        endOfWar = new Date(b.endOfWar.year,b.endOfWar.month-1,b.endOfWar.day)
        battle = new HG.Battle name, startTime, endTime, location, combatants, winner, endOfWar, @_nowDate
        @_battles.push battle

      @_battlesChanged = true
      @_filterBattles()
      )

  ############################# MAIN FUNCTIONS #################################

  # ============================================================================
  _filterBattles: ->

  	for battle in @_filteredBattles
      battle.destroy()
      battle = null

    @_filteredBattles = []

    for battle in @_battles
    	isInTime = false
    	unless @_currentTimeFilter == null
    		isInTime = not (battle.getStartTime().getTime() > @_currentTimeFilter.end.getTime()) and
                   not (battle.getEndTime().getTime() < @_currentTimeFilter.start.getTime())

      isInSpace = true
      ###unless @_currentSpaceFilter == null
        isInSpace = battle.getLocation().lat >= @_currentSpaceFilter.min.lat and
                    battle.getLocation().long >= @_currentSpaceFilter.min.long and
                    battle.getLocation().lat <= @_currentSpaceFilter.max.lat and
                    battle.getLocation().long <= @_currentSpaceFilter.max.long###

      if isInTime and isInSpace
      	@_filteredBattles.push(battle)

  	for callback in @_onBattlesChangedCallbacks
      callback @_filteredBattles

