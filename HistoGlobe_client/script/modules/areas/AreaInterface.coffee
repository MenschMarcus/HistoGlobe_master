window.HG ?= {}

# ==============================================================================
# loads geometries from the server and hands them over in a large array

class HG.AreaInterface


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onLoadInitArea'
    @addCallback 'onFinishLoadingInitAreas'
    @addCallback 'onLoadRestArea'

    # includes
    @_geometryReader = new HG.GeometryReader

  # ============================================================================
  loadInit: (@_hgInstance) ->

    request = {
      date:               moment(@_hgInstance.timeController.getNowDate()).format()
      centerLat:          @_hgInstance.map.getCenter()[0]
      centerLng:          @_hgInstance.map.getCenter()[1]
      chunkId:            0         # initial
      chunkSize:          50        # = number of areas per response
    }

    # recursively load chunks of areas from the server
    @_loadInitAreas request

  # ============================================================================
  loadRest: (@_hgInstance) ->

    request = {
      activeAreas:        []
    }

    for area in @_hgInstance.areaController.getActiveAreas()
      request.activeAreas.push area.getId()

    # recursively load chunks of areas from the server
    @_loadRestAreas request

  # ============================================================================
  convertToServerModel: (area) ->
    @_prepareAreaClientToServer area


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # recursively load all initially active areas from the server
  _loadInitAreas: (request) ->

    $.ajax
      url:  'get_init_areas/'
      type: 'POST'
      data: JSON.stringify request

      # success callback: load areas here
      success: (response) =>

        # deserialize string to object
        dataObj = $.parseJSON response

        # create an area for each feature
        $.each dataObj.features, (key, val) =>
          areaData = @_prepareAreaServerToClient val
          @notifyAll 'onLoadInitArea', new HG.Area areaData if areaData

        # finish recursion when loading is complete
        return @notifyAll 'onFinishLoadingInitAreas' if dataObj.loadingComplete

        # otherwise increment to next chunk => RECURSION PARTỲ !!!
        request.chunkId += request.chunkSize
        @_loadInitAreas request


      # error callback: print error message
      error: (xhr, errmsg, err) =>
        console.log xhr
        console.log errmsg, err
        console.log xhr.responseText


  # ============================================================================
  # load all initially inactive rest areas from the server
  _loadRestAreas: (request) ->

    $.ajax
      url:  'get_rest_areas/'
      type: 'POST'
      data: JSON.stringify request

      # success callback: load areas here
      success: (response) =>

        # deserialize string to object
        dataObj = $.parseJSON response

        # TODO: test if that works

        # create an area for each feature
        $.each dataObj.features, (key, val) =>
          areaData = @_prepareAreaServerToClient val
          @notifyAll 'onLoadRestArea', new HG.Area areaData if areaData


      # error callback: print error message
      error: (xhr, errmsg, err) =>
        console.log xhr
        console.log errmsg, err
        console.log xhr.responseText

  # ============================================================================
  _prepareAreaServerToClient: (areaFromServer) ->
    areaOnClient = {
      id :                    areaFromServer.properties.id
      geometry :              @_geometryReader.read areaFromServer.geometry
      shortName :             areaFromServer.properties.short_name
      formalName :            areaFromServer.properties.formal_name
      representativePoint :   @_geometryReader.read areaFromServer.properties.representative_point
      sovereigntyStatus :     areaFromServer.properties.sovereignty_status
      territoryOf :           @_hgInstance.areaController.getArea areaFromServer.properties.territory_of
    }

    # error handling: each area must have valid id and geometry
    return null if (not areaOnClient.id) or (not areaOnClient.geometry.isValid())

    return areaOnClient

  # ============================================================================
  _prepareAreaClientToServer: (areaFromClient) ->
    areaOnServer = {
      id :                    areaFromClient.getId()
      geometry :              areaFromClient.getGeometry().wkt()
      representative_point :  areaFromClient.getRepresentativePoint().wkt()
      short_name :            areaFromClient.getShortName()
      formal_name :           areaFromClient.getFormalName()
      sovereignty_status :    areaFromClient.getSovereigntyStatus()
      territory_of :          areaFromClient.getTerritoryOf()?.getId()
    }

    areaOnServer