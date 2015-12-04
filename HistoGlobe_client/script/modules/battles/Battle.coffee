window.HG ?= {}

class HG.Battle

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (name, startTime, endTime, location, combatants, winner, endOfWar, currentDate) ->

    @_name = name
    @_startTime = startTime
    @_endTime = endTime
    @_location = location
    @_combatants = combatants
    @_winner = winner
    @_endOfWar = endOfWar
    @_currentDate = currentDate

  # ============================================================================
  setDate: (date) ->
  	@_currentDate = date

  # ============================================================================
  getName: ->
    @_name

  # ============================================================================
  getDate: ->
    @_currentDate

  # ============================================================================
  getStartTime: ->
  	@_startTime

  # ============================================================================
  getEndTime: ->
  	@_endTime

  # ============================================================================
  getLocation: ->
  	@_location

  # ============================================================================
  getEndOfWar: ->
    @_endOfWar

  # ============================================================================
  destroy: ->
  	delete @