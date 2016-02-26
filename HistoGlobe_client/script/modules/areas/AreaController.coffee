window.HG ?= {}

class HG.AreaController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onAddArea"

    # handle config
    defaultConfig =
      JSONPaths: undefined,

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (@_hgInstance) ->
    @_hgInstance.areaController = @

    @_areas = []          # set of all HG.Area's (id, geometry, name)


    @_hgInstance.onAllModulesLoaded @, () =>
      geometryReader = new HG.GeometryReader

      for file in @_config.JSONPaths
        $.getJSON file, (areas) =>
          for area in areas.features
            id = area.id
            geometry = geometryReader.read area.geometry
            names = {'commonName': area.properties.name}
            newArea = new HG.Area id, geometry, names
            @_areas.push newArea
            @notifyAll "onAddArea", newArea


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  # find area/label
  # TODO: get better algorithm
  _getAreaById: (id) ->
    if id?
      for area in @_areas
        if area.getId() is id
          return area
    undefined
