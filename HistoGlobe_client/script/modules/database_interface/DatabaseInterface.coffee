window.HG ?= {}

# ==============================================================================
# loads initial areas and hivents from the server and creates their links
# to each other via start/end hivents and ChangeAreas/ChangeAreaNames/Territorie
# ==============================================================================

class HG.DatabaseInterface


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################


  # ============================================================================

  constructor: () ->
    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onLoadRestHivent'
    @addCallback 'onFinishLoadingRestHivents'

    @addCallback 'onLoadAreaHivents'
    @addCallback 'onFinishLoadingAreaIds'
    @addCallback 'onLoadVisibleArea'
    @addCallback 'onFinishLoadingVisibleAreas'
    @addCallback 'onLoadInvisibleArea'
    @addCallback 'onFinishLoadingInvisibleAreas'


  # ============================================================================

  hgInit: (@_hgInstance) ->

    ### temporary quick and dirty solution ###

    $.ajax
      url:  'get_all/'
      type: 'POST'
      data: ""

      # success callback: load areas and hivents here and connect them
      success: (response) =>
        dataObj = $.parseJSON response
        console.log dataObj


      error: @_errorCallback





'''
### the sophisticated version goes here this afternoon
    # --------------------------------------------------------------------------
    # loading mechanism:
    # 1) load initial area ids and create their AreaHandles
    # ->  2) load initially visible area data and create their Name/Territory
    #     ->  3) load rest visible area data and create rest Names/Territories/Hivents
    #         ->  4) load rest data (invisible areas and rest hivents)
    # --------------------------------------------------------------------------

    @_hgInstance.onAllModulesLoaded @, () =>

      # includes
      @_geometryReader = new HG.GeometryReader
      @_areaController = @_hgInstance.areaController
      @_hiventController = @_hgInstance.hiventController

    # --------------------------------------------------------------------------
    # 1) load initial area and hivent ids () ->
    #    (all areas            {id, start hivent it, end hivent id},
    #     -> current name      {id, start hivent id, end hivent id},
    #     -> current territory {id, start hivent id, end hivent id},
    #     all hivents          {id})
    #   => create Area and AreaHandle
    #   => create Hivent and HiventHandle
    # --------------------------------------------------------------------------
      @_loadInitAreaIds()

    # --------------------------------------------------------------------------
    # MAIN LOAD TO SEE INITIAL AREAS => as fast as possible
    # --------------------------------------------------------------------------
    # 2) load init visible area data ([area id, name id, territory id], [hivent id]) ->
    #    (visible area    (id),
    #     init name       (id, short name, formal name),
    #     init territory  (id, geometry, repr point))
    #   => get AreaHandle(area id)
    #   => create AreaName(init name)
    #   => create AreaTerritory (init territory)
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # 3) load rest visible area data ([area id, name id, territory id], [hivent id])
    #    (visible area      (id, predecessors, successors, sovereignt, dependencies),
    #     rest names       [(id, short name, formal name, start hivent, end hivent)],
    #     rest territories [(id, geometry, repr point, start hivent, end hivent)],
    #     hivents          [(id, ...full data...)])
    #   => get AreaHandle(area id)
    #     => update Area(predecessors, successors, sovereignt, dependencies)
    #     => create AreaNames(rest names)
    #     => create AreaTerritories(rest territories)
    #   => get HiventHandle
    #     => update Hivent
    #     => link start / end hivents of Area <-> Hivent->Change->ChangeArea
    #       (same for AreaName and AreaTerritory)
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # 4) load full invisible area data ([area id], [exisiting hivent id])
    #    (invisible area    (id, predecessors, successors, sovereignt, dependencies) +
    #     all names        [(id, short name, formal name, start hivent, end hivent)] +
    #     all territories  [(id, geometry, repr point, start hivent, end hivent)] +
    #     all rest hivents [(id, ...full data...)])
    #   => get AreaHandle(area id)
    #     => update Area(predecessors, successors, sovereignt, dependencies)
    #     => create AreaNames(rest names)
    #     => create AreaTerritories(rest territories)
    #   => get HiventHandle
    #     => link start / end hivents of Area <-> Hivent->Change->ChangeArea
    #       (same for AreaName and AreaTerritory)
    # --------------------------------------------------------------------------





  # ============================================================================
  # get initial set of information about area from the server:
  # id, start and endHivent and territorial relation
  # no name and geometry yet (to load fast which areas will eventually be there)
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

        console.log dataObj

        # create an area with id for each feature
        areaHandles = []
        $.each dataObj, (key, val) =>
          # create Area only with id
          area = new HG.Area val.id

          # create AreaHandle that is handed through the application
          areaHandle = new HG.AreaHandle area

          # little hack: set temporary loading variables that will be replaced later
          areaHandle.tempLoadVars = {
            visible:      val.visible
            predecessors: val.predecessors
            successors:   val.successors
            sovereignt:   val.sovereignt
            dependencies: val.dependencies
          }
          areaHandles.push areaHandles

          # load Hivents in HiventController
          @notifyAll 'onLoadAreaHivents', val.start_hivent, val.end_hivent, areaHandle

        # load Areas completely in AreaController
        @notifyAll 'onFinishLoadingAreaIds', areaHandles


      # error callback: print error message
      error: @_errorCallback
  # load all areas that are initially (in)visible from the server
  # ============================================================================

  loadVisibleAreas: (visibleAreas) ->
    @_loadInitAreas @_getRequest visibleAreas, 'onLoadVisibleArea', 'onFinishLoadingVisibleAreas'

  # ----------------------------------------------------------------------------
  loadInvisibleAreas: (invisibleAreas) ->
    @_loadInitAreas @_getRequest invisibleAreas, 'onLoadInvisibleArea', 'onFinishLoadingInvisibleAreas'


  # ============================================================================
  convertToServerModel: (area) ->
    @_prepareAreaClientToServer area



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # compile request header for initial area loading
  # ============================================================================

  _getRequest: (areaIds, areaLoadCallback, finishCallback) ->

    request = {
      areaIds:            areaIds
      centerLat:          @_hgInstance.map.getCenter()[0]
      centerLng:          @_hgInstance.map.getCenter()[1]
      chunkId:            0  # initial value
      chunkSize:          HGConfig.area_loading_chunk_size.val
      areaLoadCallback:   areaLoadCallback
      finishCallback:     finishCallback
    }


  # ============================================================================
  # recursively load all initially active areas from the server
  # ============================================================================

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


    # # get list of all associated names and their creation date
    # current_name = None
    # for name in AreaName.objects.filter(area=self):

    #   # get start and end date of the name
    #   start_date = name.start_change.hivent.effect_date
    #   try:
    #     end_date = name.end_change.hivent.effect_date
    #   except:
    #     end_date = timezone.now()

    #   # pick the 1 name that is inside the start and end date
    #   if (start_date <= request_date) and (request_date < end_date):
    #     current_name = name
    #     break



        # finish recursion when loading is complete
        return @notifyAll request.finishCallback if dataObj.loadingComplete

        # otherwise increment to next chunk => RECURSION PARTỲ !!!
        request.chunkId += request.chunkSize
        @_loadInitAreas request

      # error callback: print error message
      error: @_errorCallback

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
      # start/end hivent are handled by HiventController
      # startHivent :           areaFromServer.properties.start_hivent
      # endHivent :             areaFromServer.properties.end_hivent
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
      start_hivent:           areaFromClient.getStartHivent()?.getHivent().id
      end_hivent:             areaFromClient.getEndHivent()?.getHivent().id
    }

    areaOnServer

  # ============================================================================
  loadRestHivents: (hiventHandles) ->

    request = {
      hiventIds: []
    }
    for hiventHandle in hiventHandles
      request.hiventIds.push hiventHandle.getHivent().id

    $.ajax
      url:  'get_rest_hivents/'
      type: 'POST'
      data: JSON.stringify request

      # success callback: load hivents here
      success: (response) =>

        # deserialize string to object
        dataObj = $.parseJSON response

        $.each dataObj, (key, val) =>
          @notifyAll 'onLoadRestHivent', @loadFromServerModel val

        @notifyAll 'onFinishLoadingRestHivents'

      # error callback: print error message
      error: @_errorCallback


  # ============================================================================
  loadFromServerModel: (hiventFromServer) ->
    @_prepareHiventServerToClient hiventFromServer


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _prepareHiventServerToClient: (hiventFromServer) ->

    # error handling: id and name must be given
    return null if (not hiventFromServer.id) or (not hiventFromServer.name)

    hiventData = {
      id :                hiventFromServer.id
      name :              hiventFromServer.name
      startDate :         moment(hiventFromServer.start_date)
      endDate :           moment(hiventFromServer.end_date?)
      effectDate :        moment(hiventFromServer.effect_date)
      secessionDate :     moment(hiventFromServer.secession_date?)
      displayDate :       moment(hiventFromServer.display_date?)
      locationName :      hiventFromServer.location_name          ?= null
      locationPoint :     hiventFromServer.location_point         ?= null
      locationArea :      hiventFromServer.location_area          ?= null
      description :       hiventFromServer.description            ?= null
      linkUrl :           hiventFromServer.link_url               ?= null
      linkDate :          moment(hiventFromServer.link_date?)
      changes :           []
    }

    # prepare changes
    for change in hiventFromServer.changes
      changeData = {
        operation:  change.operation
        oldAreas:   []
        newAreas:   []
      }
      # create unique array (each area is only once in the old/newArea array)
      for area in change.change_areas
        changeData.oldAreas.push area.old_area if (area.old_area?) and (changeData.oldAreas.indexOf(area.old_area) is -1)
        changeData.newAreas.push area.new_area if (area.new_area?) and (changeData.newAreas.indexOf(area.new_area) is -1)
      # add change to hivent
      hiventData.changes.push changeData

    return hiventData

  # ============================================================================
  # _prepareHiventClientToServer: (hiventFromServer) ->


  _errorCallback: (xhr, errmsg, err) =>
    console.log xhr
    console.log errmsg, err
    console.log xhr.responseText

  # ============================================================================
  # TODO:
  # allow multiple locations per hivent
  # data.location = data.location?.replace(/\s*;\s*/g, ';').split(';')
  # data.lat = "#{data.lat}".replace(/\s*;\s*/g, ';').split(';') if data.lat?
  # data.lng = "#{data.lng}".replace(/\s*;\s*/g, ';').split(';') if data.lng?
'''