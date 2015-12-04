window.HG ?= {}

class HG.BattlesOnMap

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    @_map = null
    @_battleController = null
    @_battleMarkers = []


  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.battlesOnMap = @

    @_map = hgInstance.map._map

    @_battleController = hgInstance.battleController

    if @_battleController
      @_initBattles()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initBattles: ->

    @_battleMarkers = []

    @_battleController.onBattlesChanged (battles) =>
      addedBattles = []
      for battleMarker in @_battleMarkers
        addedBattle = battleMarker.getBattle()
        addedBattles.push addedBattle
      for b in battles
        if b not in addedBattles
          newBattleMarker = new HG.BattleMarker2D b, this, @_map
          @_battleMarkers.push newBattleMarker
        else
          for bm in @_battleMarkers
            if b is bm.getBattle()
              bm.update()

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################