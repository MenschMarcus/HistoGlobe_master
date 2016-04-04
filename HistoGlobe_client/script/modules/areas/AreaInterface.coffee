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

    @addCallback 'onFinishLoadingAreaIds'
    @addCallback 'onLoadActiveArea'
    @addCallback 'onFinishLoadingActiveAreas'
    @addCallback 'onLoadInactiveArea'
    @addCallback 'onFinishLoadingInactiveAreas'

    # includes
    @_geometryReader = new HG.GeometryReader

  # ============================================================================
  loadAllAreaIds: (@_hgInstance) ->

    request = {
      date: moment(@_hgInstance.timeController.getNowDate()).format()
    }

    $.ajax
      url:  'get_init_area_ids/'
      type: 'POST'
      data: JSON.stringify request

      # success callback: load areas here
      success: (response) =>

        # deserialize string to object
        dataObj = $.parseJSON response

        # create an area with id for each feature
        areas = []
        $.each dataObj, (key, val) =>
          area = new HG.Area val.id
          area.activate() if val.active
          areas.push area

        @notifyAll 'onFinishLoadingAreaIds', areas


      # error callback: print error message
      error: (xhr, errmsg, err) =>
        console.log xhr
        console.log errmsg, err
        console.log xhr.responseText


  # ============================================================================
  loadActiveAreas: (@_hgInstance, activeAreas) ->

    areaIds = []
    areaIds.push area.getId() for area in activeAreas

    request = {
      areas:              areaIds
      centerLat:          @_hgInstance.map.getCenter()[0]
      centerLng:          @_hgInstance.map.getCenter()[1]
      chunkId:            0  # initial value
      chunkSize:          HGConfig.area_loading_chunk_size.val
      areaLoadCallback:   'onLoadActiveArea'
      finishCallback:     'onFinishLoadingActiveAreas'
    }

    # recursively load chunks of areas from the server
    @_loadInitAreas request


  # ============================================================================
  loadInactiveAreas: (@_hgInstance, inactiveAreas) ->

    areaIds = []
    areaIds.push area.getId() for area in inactiveAreas

    request = {
      areas:              areaIds
      centerLat:          @_hgInstance.map.getCenter()[0]
      centerLng:          @_hgInstance.map.getCenter()[1]
      chunkId:            0  # initial value
      chunkSize:          HGConfig.area_loading_chunk_size.val
      areaLoadCallback:   'onLoadInactiveArea'
      finishCallback:     'onFinishLoadingInactiveAreas'
    }

    # recursively load chunks of areas from the server
    @_loadInitAreas request


  # ============================================================================
  convertToServerModel: (area) ->
    @_prepareAreaClientToServer area

  # ============================================================================
  copyArea: (inArea, newAreaId) ->

    # error handling new id must be given to avoid duplicate ids
    if not newAreaId
      return console.error "an idea for the copied area has to be given to avoid duplicate area ids"

    areaData = {
      geometry:             inArea.getGeometry().wkt()
      representativePoint:  inArea.getRepresentativePoint().wkt()
      shortName:            inArea.getShortName()
      formalName:           inArea.getFormalName()
      sovereigntyStatus:    inArea.getSovereigntyStatus()
      territoryOf:          inArea.getTerritoryOf()
      isActive:             inArea.isActive()
      isSelected:           inArea.isSelected()
      isFocused:            inArea.isFocused()
      isInEdit:             inArea.isInEdit()
    }
    # deep copy, to be on the safe side
    areaData = JSON.parse(JSON.stringify(areaData))

    outArea = new HG.Area newAreaId
    outArea.setGeometry             @_geometryReader.read areaData.geometry
    outArea.setRepresentativePoint  @_geometryReader.read areaData.representativePoint
    outArea.setShortName            areaData.shortName
    outArea.setFormalName           areaData.formalName
    outArea.setSovereigntyStatus    areaData.sovereigntyStatus
    outArea.setTerritoryOf          areaData.territoryOf
    outArea.activate()              if areaData.isActive
    outArea.select()                if areaData.isSelected
    outArea.focus()                 if areaData.isFocused
    outArea.inEdit yes              if areaData.isInEdit

    outArea


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

        # update area properties for each loaded area
        $.each dataObj.features, (key, val) =>
          areaData = @_prepareAreaServerToClient val
          area = @_hgInstance.areaController.getArea areaData.id

          area.setGeometry areaData.geometry
          area.setRepresentativePoint areaData.representativePoint
          area.setShortName areaData.shortName
          area.setFormalName areaData.formalName
          area.setSovereigntyStatus areaData.sovereigntyStatus
          area.setTerritoryOf areaData.territoryOf

          @notifyAll request.areaLoadCallback, area

        # finish recursion when loading is complete
        return @notifyAll request.finishCallback if dataObj.loadingComplete

        # otherwise increment to next chunk => RECURSION PARTỲ !!!
        request.chunkId += request.chunkSize
        @_loadInitAreas request

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

    areaOnClient

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