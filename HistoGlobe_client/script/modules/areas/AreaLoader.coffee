window.HG ?= {}

# ==============================================================================
# loads geometries from the server and hands them over in a large array

class HG.AreaLoader


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onFinishLoading'

    # external module
    @_geometryReader = new HG.GeometryReader

  # ============================================================================
  loadInit: () ->

    # initially load them from file
    # TODO: exchange with real fetcching from the database

    request =
      date:       moment(@_hgInstance.timeline.getNowDate()).format()
      centerLat:  @_hgInstance.map.getCenter()[0]
      centerLng:  @_hgInstance.map.getCenter()[1]
      chunkId:    0         # initial
      chunkSize:  50        # = number of areas per response

    # recursively load chunks of areas from the server
    return @_loadAreasFromServer request



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # recursively load all areas from the server
  _loadAreasFromServer: (request) ->

    $.ajax
      url:  'get_initial_areas/'
      type: 'POST'
      data: JSON.stringify request

      # success callback: load areas here
      success: (response) =>

        # deserialize string to object
        dataObj = $.parseJSON response

        # create an area for each feature
        $.each dataObj.features, (key, val) =>

          id =                    val.properties.id
          nameShort =             val.properties.name_short
          nameFormal =            val.properties.name_formal
          geometry =              @_geometryReader.read val.geometry
          representativePoint =   @_geometryReader.read val.properties.representative_point
          internationalStatus =   val.properties.international_status
          sovereigntyStatus =     val.properties.sovereignty_status
          territoryOf =           val.properties.territory_of

          # error handling: each area must have valid id and geometry
          return if not id
          return if not geometry.isValid()

          # create new area
          @notifyAll 'onFinishLoading', new HG.Area(
            id, nameShort, nameFormal, geometry, representativePoint,
            internationalStatus, sovereigntyStatus, territoryOf)


        # finish recursion when loading is complete
        return if dataObj.loadingComplete

        # otherwise increment to next chunk => RECURSION PARTỲ !!!
        request.chunkId += request.chunkSize
        @_loadAreasFromServer request


      # callback: print error message
      error: (xhr, errmsg, err) =>
        console.log xhr
        console.log errmsg, err
        console.log xhr.responseText

