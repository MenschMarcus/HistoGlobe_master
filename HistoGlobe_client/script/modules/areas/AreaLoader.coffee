window.HG ?= {}

# ==============================================================================
# loads geometries from the server and hands them over in a large array

class HG.AreaLoader


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
      date:               moment(@_hgInstance.timeline.getNowDate()).format()
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
          areaData = @_prepareArea val
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
          areaData = @_prepareArea val
          @notifyAll 'onLoadRestArea', new HG.Area areaData if areaData


      # error callback: print error message
      error: (xhr, errmsg, err) =>
        console.log xhr
        console.log errmsg, err
        console.log xhr.responseText

  # ============================================================================
  # load all initially inactive rest areas from the server
  _prepareArea: (data) ->
    area = {
      id :                    data.properties.id
      geometry :              @_geometryReader.read data.geometry
      shortName :             data.properties.name_short
      formalName :            data.properties.name_formal
      representativePoint :   @_geometryReader.read data.properties.representative_point
      sovereigntyStatus :     data.properties.sovereignty_status
      territoryOf :           data.properties.territory_of
    }

    # error handling: each area must have valid id and geometry
    return null if (not area.id) or (not area.geometry.isValid())

    return area
