window.HG ?= {}

class HG.CrowdsOnMap

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    @_map = null
    @_timeline = null
    @_crowdController = null
    @_crowdMarkers = []


  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.crowdsOnMap = @


    @_map = hgInstance.map._map

    @_timeline = hgInstance.timeline

    @_crowdController = hgInstance.crowdController

    if @_crowdController
      @_initCrowds()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initCrowds: ->

    @_crowdMarkers = []

    #for crowd in @_crowdController.getCrowds()
      #crowdMarker = new HG.CrowdMarker2D crowd, this, @_map
      #@_crowdMarkers.push crowdMarker

    @_crowdController.onCrowdsChanged (crowds) =>
      addedCrowds = []
      for crowdMarker in @_crowdMarkers
        addedCrowd = crowdMarker.getCrowd()
        addedCrowds.push addedCrowd
      for c in crowds
        if c not in addedCrowds
          newCrowdMarker = new HG.CrowdMarker2D c, this, @_map, @_timeline
          @_crowdMarkers.push newCrowdMarker
        else
          # get crowdmarker (for known crowd) and update
          for cm in @_crowdMarkers
            if c is cm.getCrowd()
              cm.update()

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################