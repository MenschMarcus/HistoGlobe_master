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

    @addCallback 'onFinishLoadingInitData'
    @addCallback 'onFinishSavingHistoricalOperation'


  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add to hg instance
    @_hgInstance.databaseInterface = @

    # include
    @_geometryReader = new HG.GeometryReader

    # temporary quick and dirty solution
    # that actually works quite well for now :P

    $.ajax
      url:  'get_all/'
      type: 'POST'
      data: ""

      # success callback: load areas and hivents here and connect them
      success: (response) =>
        dataObj = $.parseJSON response

        # create Areas
        for areaData in dataObj.areas
          area = new HG.Area areaData.id
          areaHandle = new HG.AreaHandle @_hgInstance, area
          area.handle = areaHandle

        # create AreaNames and AreaTerritories and store them
        # so they can be linked to ChangeAreas later
        areaNames = []
        for anData in dataObj.area_names
          anData = @_areaNameToClient anData
          areaName = new HG.AreaName anData
          areaName.area = anData.area
          areaNames.push areaName

        areaTerritories = []
        for atData in dataObj.area_territories
          atData = @_areaTerritoryToClient atData
          areaTerritory = new HG.AreaTerritory atData
          areaTerritory.area = atData.area
          areaTerritories.push areaTerritory

        # keep track of earliest data to know where to start tracing the changes
        minDate = moment()

        # create Hivents
        for hData in dataObj.hivents
          hivent = new HG.Hivent @_hiventToClient hData
          minDate = moment.min(minDate, hivent.effectDate)

          # create HistoricalChanges
          for hcData in hData.historical_changes
            hcData = @_historicalChangeToClient hcData
            hcData = @_validateHistoricalChange hcData
            historicalChange = new HG.HistoricalChange  hcData.id
            historicalChange.operation =                hcData.operation
            historicalChange.hivent =                   hcData.hivent

            # create AreaChanges
            for acData in hcData.areaChanges
              acData = @_areaChangeToClient acData, areaNames, areaTerritories
              acData = @_validateAreaChange acData
              areaChange = new HG.AreaChange acData.id
              areaChange.operation =        acData.operation
              areaChange.historicalChange = historicalChange
              areaChange.area =             acData.area
              areaChange.oldAreaName =      acData.oldAreaName
              areaChange.newAreaName =      acData.newAreaName
              areaChange.oldAreaTerritory = acData.oldAreaTerritory
              areaChange.newAreaTerritory = acData.newAreaTerritory

              # link HistoricalChange <- ChangeArea
              historicalChange.areaChanges.push areaChange

              # link ChangeArea <- Area / AreaName / AreaTerritory
              switch areaChange.operation

                when 'ADD'
                  areaChange.area.startChange =             areaChange
                  areaChange.newAreaName.startChange =      areaChange
                  areaChange.newAreaTerritory.startChange = areaChange

                when 'DEL'
                  areaChange.area.endChange =               areaChange
                  areaChange.oldAreaName.endChange =        areaChange
                  areaChange.oldAreaTerritory.endChange =   areaChange

                when 'TCH'
                  areaChange.area.updateChanges.push        areaChange
                  areaChange.oldAreaTerritory.endChange =   areaChange
                  areaChange.newAreaTerritory.startChange = areaChange

                when 'NCH'
                  areaChange.area.updateChanges.push        areaChange
                  areaChange.oldAreaName.endChange =        areaChange
                  areaChange.newAreaName.startChange =      areaChange

              # link Hivent <- HistoricalChange
              hivent.historicalChanges.push historicalChange

          # finalize handle
          hiventHandle = new HG.HiventHandle @_hgInstance, hivent
          hivent.handle = hiventHandle
          @_hgInstance.hiventController.addHiventHandle hiventHandle

        # DONE!
        # hack: make min date slightly smaller to detect also first change
        newMinDate = minDate.clone()
        newMinDate.subtract 10, 'year'
        @notifyAll 'onFinishLoadingInitData', newMinDate

      error: @_errorCallback


  # ============================================================================
  # Save the outcome of an historical Operation to the server: the Hivent,
  # its associated HistoricalChange and their AreaChanges, including their
  # associated Areas, AreaNames and AreaTerritories.
  # All objects have temporary IDs, the server will create real IDs and return
  # them. This function also updates the IDs.
  # ============================================================================

  saveHistoricalOperation: (hiventData, historicalChange) ->

    # request data sent to the server

    request = {
      hivent:               null
      hivent_status:        null # 'new' or 'upd'
      historical_change:    {}
      new_areas:            []
      new_area_names:       []
      new_area_territories: []
    }

    # assemble relevant data for the request, resolving the circular double-link
    # structure to a one-directional hierarchical structure:
    # Hivent -> HistoricalChange -> [AreaChange] --> Area
    #                                            |-> AreaName / AreaTerritory

    ## Hivent: create new or update?
    if hiventData.status is 'new' #   => create new Hivent
      hivent = new HG.Hivent hiventData
      hiventHandle = new HG.HiventHandle @_hgInstance, hivent
      hivent.handle = hiventHandle

    else # hiventData.status is 'upd' => update existing Hivent
      hiventHandle = @_hgInstance.hiventController.getHiventHandle hiventData.id
      hivent = hiventHandle.getHivent()
      # override hivent data with new info from server
      $.extend hivent, hiventData

    # add to request
    request.hivent = @_hiventToServer hivent
    request.hivent_status = hiventData.status


    ## HistoricalChange: omit Hivent (link upward)
    request.historical_change_data = {
      id:           historicalChange.id
      operation:    historicalChange.operation
      area_changes: []  # store only ids, so they can be associated
    }

    ## AreaChanges: omit HistoricalChange (link upward), save only ids of Areas
    for areaChange in historicalChange.areaChanges
      request.historical_change_data.area_changes.push {
        id:                   areaChange.id
        operation:            areaChange.operation
        area:                 areaChange.area.id
        old_area_name:        areaChange.oldAreaName?.id
        old_area_territory:   areaChange.oldAreaTerritory?.id
        new_area_name:        areaChange.newAreaName?.id
        new_area_territory:   areaChange.newAreaTerritory?.id
      }

      ## new Area is part of each ADD operation
      if areaChange.operation is 'ADD'
        request.new_areas.push {
          id:   areaChange.area.id
        }

      ## new AreaName is part of each ADD and NCH operation
      if areaChange.operation is 'ADD' or areaChange.operation is 'NCH'
        request.new_area_names.push {
          id:           areaChange.newAreaName.id
          short_name:   areaChange.newAreaName.shortName
          formal_name:  areaChange.newAreaName.formalName
        }

      ## new AreaTerritory is part of each ADD and TCH operation
      if areaChange.operation is 'ADD' or areaChange.operation is 'TCH'
        request.new_area_territories.push {
          id:                   areaChange.newAreaTerritory.id
          geometry:             areaChange.newAreaTerritory.geometry.wkt()
          representative_point: areaChange.newAreaTerritory.representativePoint.wkt()
        }

      # make hivent and historicalChange accessible in success callback
      @_hivent =            hivent
      @_historicalChange =  historicalChange


  ### get request from EditMode -> Test Button ###
  testSave: (request) ->

    $.ajax
      url:  'save_operation/'
      type: 'POST'
      data: JSON.stringify request

      # success callback: load areas and hivents here and connect them
      success: (response) =>
        dataObj = $.parseJSON response

        ### UPDATE IDS AND ESTABLISH DOUBLE-LINKS ###

        ## Hivent: update with possibly new data from server
        @_hivent = $.extend @_hivent, @_hiventToClient response.hivent


        ## HistoricalChange
        @_historicalChange.id = response.historical_change.new_id

        # Hivent <-> HistoricalChange
        hivent.historicalChanges.push @_historicalChange
        @_historicalChange.hivent = hivent


        ## AreaChanges
        for areaChange in @_historicalChange.areasChanges

          # find associated areaChangeData id in response data
          for area_change in response.historical_change.area_changes
            if areaChange.id is area_change.old_id

              # update id
              areaChange.id = area_change.new_id

              ## Area
              areaChange.area.id = area_change.area_id

              # AreaChange <- Area
              switch areaChange.operation
                when 'ADD' then         areaChange.area.startChange =       areaChange
                when 'DEL' then         areaChange.area.endChange =         areaChange
                when 'TCH', 'NCH' then  areaChange.area.updateChanges.push  areaChange

              ## AreaName
              if areaChange.oldAreaName
                # id is already up to data
                # AreaChange <- AreaName
                areaChange.oldAreaName.endChange = areaChange

              if areaChange.newAreaName
                # update id
                areaChange.newAreaName.id = area_change.new_area_name_id
                # AreaChange <- AreaName
                areaChange.newAreaName.startChange = areaChange

              ## AreaTerritory
              if areaChange.oldAreaTerritory
                # id is already up to data
                # AreaChange <- AreaTerritory
                areaChange.oldAreaTerritory.endChange = areaChange

              if areaChange.newAreaTerritory
                # update id
                areaChange.newAreaTerritory.id = area_change.new_area_territory_id
                # AreaChange <- AreaTerritory
                areaChange.newAreaTerritory.startChange = areaChange


      error: @_errorCallback



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  # data objects from the client to the server to each other
  # ============================================================================

  _areaTerritoryToServer: (dataObj) ->
    {
      id:                   parseInt dataObj.id
      geometry:             dataObj.geometry.wkt()
      representative_point: dataObj.representativePoint.wkt()
      area:                 dataObj.area?.id
      start_change:         dataObj.startChange?.id
      end_change:           dataObj.endChange?.id
    }

  # ----------------------------------------------------------------------------
  _areaTerritoryToClient: (dataObj) ->
    {
      id:                   parseInt dataObj.id
      geometry:             @_geometryReader.read dataObj.geometry
      representativePoint:  @_geometryReader.read dataObj.representative_point
      area:                 (@_hgInstance.areaController.getAreaHandle dataObj.area).getArea()
      startChange:          dataObj.start_change  # only id!
      endChange:            dataObj.end_change    # only id!
    }

  # ----------------------------------------------------------------------------
  _areaNameToServer: (dataObj) ->
    {
      id:                   parseInt dataObj.id
      short_name:           dataObj.shortName
      formal_name:          dataObj.formalName
      area:                 dataObj.area?.id
      start_change:         dataObj.startChange?.id
      end_change:           dataObj.endChange?.id
    }

  # ----------------------------------------------------------------------------
  _areaNameToClient: (dataObj) ->
    {
      id:                   parseInt dataObj.id
      shortName:            dataObj.short_name
      formalName:           dataObj.formal_name
      area:                 (@_hgInstance.areaController.getAreaHandle dataObj.area).getArea()
      startChange:          dataObj.start_change  # only id!
      endChange:            dataObj.end_change    # only id!
    }

  # ----------------------------------------------------------------------------
  _hiventToClient: (dataObj) ->
    {
      id :                dataObj.id
      name :              dataObj.name
      startDate :         moment(dataObj.start_date)
      endDate :           moment(dataObj.end_date?)
      effectDate :        moment(dataObj.effect_date)
      secessionDate :     moment(dataObj.secession_date?)
      displayDate :       moment(dataObj.display_date?)
      locationName :      dataObj.location_name          ?= null
      locationPoint :     if dataObj.location_point then @_geometryReader.read dataObj.location_point else null
      locationArea :      if dataObj.location_area  then @_geometryReader.read dataObj.location_area  else null
      description :       dataObj.description            ?= null
      linkUrl :           dataObj.link_url               ?= null
      linkDate :          moment(dataObj.link_date?)
    }

  # ----------------------------------------------------------------------------
  _hiventToServer: (dataObj) ->
    {
      id :                dataObj.id
      name :              dataObj.name
      start_date :        dataObj.startDate
      end_date :          dataObj.endDate
      effect_date :       dataObj.effectDate
      secession_date :    dataObj.secessionDate
      location_name :     dataObj.locationName
      location_point :    dataObj.locationPoint?.wkt()
      location_area :     dataObj.locationArea?.wkt()
      description :       dataObj.description
      link_url :          dataObj.linkUrl
      link_date :         dataObj.linkData
    }

  # ----------------------------------------------------------------------------
  _historicalChangeToClient: (dataObj) ->
    {
      id:           parseInt dataObj.id
      operation:    dataObj.operation
      hivent:       dataObj.hivent
      areaChanges:  dataObj.area_changes  # not changed, yet
    }

  # ----------------------------------------------------------------------------
  _historicalChangeToServer: (dataObj) ->
    # TODO if necessary

  # ----------------------------------------------------------------------------
  _areaChangeToClient: (dataObj, areaNames, areaTerritories) ->
    {
      id:               parseInt dataObj.id
      operation:        dataObj.operation
      historicalChange: dataObj.historical_change # not changed, yet
      area:             (@_hgInstance.areaController.getAreaHandle dataObj.area)?.getArea()
      oldAreaName:      areaNames.filter (obj) -> obj.id is dataObj.old_area_name
      newAreaName:      areaNames.filter (obj) -> obj.id is dataObj.new_area_name
      oldAreaTerritory: areaTerritories.filter (obj) -> obj.id is dataObj.old_area_territory
      newAreaTerritory: areaTerritories.filter (obj) -> obj.id is dataObj.new_area_territory
    }

  # ----------------------------------------------------------------------------
  _areaChangeToServer: (dataObj) ->
    # TODO if necessary


  # ============================================================================
  # validation for all data in HistoricalChange
  # ensures that HistoricalChange can correctly be executed
  # ============================================================================

  _validateHistoricalChange: (dataObj) ->

    # check if id is a number
    if isNaN(dataObj.id)
      return console.error "The id is not valid"

    # check if operation type is correct
    if ['CRE','UNI','INC','SEP','SEC','NCH','TCH','DES'].indexOf(dataObj.operation) is -1
      return console.error "The operation type " + dataObj.operation + " is not valid"

    # got all the way here? Then everything is good :)
    return dataObj


  # ============================================================================
  # validation for all data in AreaChange
  # ensures that AreaChange can correctly be executed
  # ============================================================================

  _validateAreaChange: (dataObj) ->

    # check if id is a number
    dataObj.id = parseInt dataObj.id
    if isNaN(dataObj.id)
      return console.error "The id is not valid"
    # check if operation type is correct
    if ['ADD','DEL','TCH','NCH'].indexOf(dataObj.operation) is -1
      return console.error "The operation type " + dataObj.operation + " is not valid"

    # check if area is given
    if not dataObj.area
      return console.error "The associated Area could not been found"

    # check if old/new area name/territories are singular
    if dataObj.oldAreaName.length is 0
      dataObj.oldAreaName = null
    else if dataObj.oldAreaName.length is 1
      dataObj.oldAreaName = dataObj.oldAreaName[0]
    else
      return console.error "There have been multiple AreaNames found, this is impossible"

    if dataObj.newAreaName.length is 0
      dataObj.newAreaName = null
    else if dataObj.newAreaName.length is 1
      dataObj.newAreaName = dataObj.newAreaName[0]
    else
      return console.error "There have been multiple AreaNames found, this is impossible"

    if dataObj.oldAreaTerritory.length is 0
      dataObj.oldAreaTerritory = null
    else if dataObj.oldAreaTerritory.length is 1
      dataObj.oldAreaTerritory = dataObj.oldAreaTerritory[0]
    else
      return console.error "There have been multiple AreaTerritorys found, this is impossible"

    if dataObj.newAreaTerritory.length is 0
      dataObj.newAreaTerritory = null
    else if dataObj.newAreaTerritory.length is 1
      dataObj.newAreaTerritory = dataObj.newAreaTerritory[0]
    else
      return console.error "There have been multiple AreaTerritorys found, this is impossible"

    # check if operation has necessary new/old area name/territory
    switch dataObj.operation

      when 'ADD'
        if not (
            (dataObj.newAreaName)           and
            (dataObj.newAreaTerritory)      and
            (not dataObj.oldAreaName)       and
            (not dataObj.oldAreaTerritory)
          )
          return console.error "The ADD operation does not have the expected data provided"

      when 'DEL'
        if not (
            (not dataObj.newAreaName)       and
            (not dataObj.newAreaTerritory)  and
            (dataObj.oldAreaName)           and
            (dataObj.oldAreaTerritory)
          )
          return console.error "The DEL operation does not have the expected data provided"

      when 'TCH'
        if not (
            (not dataObj.newAreaName)       and
            (dataObj.newAreaTerritory)      and
            (not dataObj.oldAreaName)       and
            (dataObj.oldAreaTerritory)
          )
          return console.error "The TCH operation does not have the expected data provided"

      when 'NCH'
        if not (
            (dataObj.newAreaName)           and
            (not dataObj.newAreaTerritory)  and
            (dataObj.oldAreaName)           and
            (not dataObj.oldAreaTerritory)
          )
          return console.error "The NCH operation does not have the expected data provided"

    # got all the way here? Then everything is good :)
    return dataObj


    # ==========================================================================
    # error callback
    # ==========================================================================

    _errorCallback: (xhr, status, errorThrown) ->
      console.log xhr
      console.log status
      console.log errorThrown