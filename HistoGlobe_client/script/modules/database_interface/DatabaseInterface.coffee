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
        areas = []
        for areaData in dataObj.areas
          area = new HG.Area areaData
          areaHandle = new HG.AreaHandle @_hgInstance, area
          area.handle = areaHandle
          areas.push area

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
          minDate = moment.min(minDate, hivent.date)

          # create HistoricalChanges
          for hcData in hData.historical_changes
            hcData = @_historicalChangeToClient hcData
            hcData = @_validateHistoricalChange hcData
            historicalChange = new HG.HistoricalChange hcData

            # create AreaChanges
            for acData in hcData.areaChanges
              acData = @_areaChangeToClient acData, areaNames, areaTerritories
              acData = @_validateAreaChange acData

              # assemble AreaChange and link to Area(Name/Territory)
              areaChangeData = {
                id:           acData.id
                hgOperation:  acData.hgOperation
                oldAreas:     []
                newAreas:     []
                updateArea:   null
              }

              for oldArea in acData.oldAreas
                areaChangeData.oldAreas.push {
                  area:       areas.find (obj) -> obj.id is oldArea.area
                  name:       areaNames.find (obj) -> obj.id is oldArea.name
                  territory:  areaTerritories.find (obj) -> obj.id is oldArea.territory
                }

              for newArea in acData.newAreas
                areaChangeData.newAreas.push {
                  area:       areas.find (obj) -> obj.id is newArea.area
                  name:       areaNames.find (obj) -> obj.id is newArea.name
                  territory:  areaTerritories.find (obj) -> obj.id is newArea.territory
                }

              if acData.updateArea
                updArea = acData.updateArea
                areaChangeData.updateArea = {
                  area:         areas.find (obj) -> obj.id is updArea.area
                  oldName:      areaNames.find (obj) -> obj.id is updArea.old_name
                  newName:      areaNames.find (obj) -> obj.id is updArea.new_name
                  oldTerritory: areaTerritories.find (obj) -> obj.id is updArea.old_territory
                  newTerritory: areaTerritories.find (obj) -> obj.id is updArea.new_territory
                }

              areaChange = new HG.AreaChange areaChangeData

              # link HistoricalChange <-> ChangeArea
              areaChange.historicalChange = historicalChange
              historicalChange.areaChanges.push areaChange

            # link Hivent <-> HistoricalChange
            historicalChange.hivent = hivent
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
      hivent_is_new:        yes
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
    if hiventData.isNew   # => create new Hivent
      hivent = new HG.Hivent hiventData
      hiventHandle = new HG.HiventHandle @_hgInstance, hivent
      hivent.handle = hiventHandle

    else # not isNew        => update existing Hivent
      hiventHandle = @_hgInstance.hiventController.getHiventHandle hiventData.id
      hivent = hiventHandle.getHivent()
      # override hivent data with new info from server
      $.extend hivent, hiventData

    # add to request
    request.hivent = @_hiventToServer hivent
    request.hivent_is_new = hiventData.isNew


    ## HistoricalChange: omit Hivent (link upward)
    request.historical_change = {
      id:           historicalChange.id
      operation:    historicalChange.operation
      area_changes: []  # store only ids, so they can be associated
    }

    ## AreaChanges: omit HistoricalChange (link upward), save only ids of Areas
    for areaChange in historicalChange.areaChanges
      request.historical_change.area_changes.push {
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


      $.ajax
        url:  'save_operation/'
        type: 'POST'
        data: JSON.stringify request

        # success callback: load areas and hivents here and connect them
        success: (response) =>

          dataObj = $.parseJSON response

          ### UPDATE IDS AND ESTABLISH DOUBLE-LINKS ###

          ## Hivent: update with possibly new data from server
          @_hivent = $.extend @_hivent, @_hiventToClient dataObj.hivent


          ## HistoricalChange
          @_historicalChange.id = dataObj.historical_change_id

          # Hivent <-> HistoricalChange
          hivent.historicalChanges.push @_historicalChange
          @_historicalChange.hivent = hivent


          ## AreaChanges
          for areaChange in @_historicalChange.areaChanges

            # find associated areaChangeData id in response data
            for area_change in dataObj.area_changes
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

          # finalize: make Hivent known to HistoGlobe (HiventController)
          @_hgInstance.hiventController.addHiventHandle @_hivent.handle
          @notifyAll 'onFinishSavingHistoricalOperation'

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
    }

  # ----------------------------------------------------------------------------
  _areaTerritoryToClient: (dataObj) ->
    {
      id:                   parseInt dataObj.id
      geometry:             @_geometryReader.read dataObj.geometry
      representativePoint:  @_geometryReader.read dataObj.representative_point
      area:                 dataObj.area # only id
    }

  # ----------------------------------------------------------------------------
  _areaNameToServer: (dataObj) ->
    {
      id:           parseInt dataObj.id
      short_name:   dataObj.shortName
      formal_name:  dataObj.formalName
      area:         dataObj.area?.id
    }

  # ----------------------------------------------------------------------------
  _areaNameToClient: (dataObj) ->
    {
      id:           parseInt dataObj.id
      shortName:    dataObj.short_name
      formalName:   dataObj.formal_name
      area:         dataObj.area # only id
    }

  # ----------------------------------------------------------------------------
  _hiventToClient: (dataObj) ->
    {
      id:           dataObj.id
      name:         dataObj.name
      date:         moment(dataObj.date)
      location:     dataObj.location    ?= null
      description:  dataObj.description ?= null
      link:         dataObj.link        ?= null
    }

  # ----------------------------------------------------------------------------
  _hiventToServer: (dataObj) ->
    {
      id:           dataObj.id
      name:         dataObj.name
      date:         dataObj.date
      location:     dataObj.location
      description:  dataObj.description
      link:         dataObj.link
    }

  # ----------------------------------------------------------------------------
  _historicalChangeToClient: (dataObj) ->
    {
      id:             parseInt dataObj.id
      editOperation:  dataObj.edit_operation
      hivent:         dataObj.hivent
      areaChanges:    dataObj.area_changes  # not changed, yet
    }

  # ----------------------------------------------------------------------------
  _historicalChangeToServer: (dataObj) ->
    # TODO if necessary

  # ----------------------------------------------------------------------------
  _areaChangeToClient: (dataObj, areaNames, areaTerritories) ->
    {
      id:               parseInt dataObj.id
      historicalChange: dataObj.historical_change # not changed, yet
      hgOperation:      dataObj.hg_operation
      oldAreas:         dataObj.old_areas
      newAreas:         dataObj.new_areas
      updateArea:       dataObj.update_area
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
    if ['CRE','MRG','DIS','CHB','REN','CES'].indexOf(dataObj.editOperation) is -1
      return console.error "The operation type " + dataObj.editOperation + " is not valid"

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
    if ['UNI','INC','SEP','SEC','NCH'].indexOf(dataObj.hgOperation) is -1
      return console.error "The operation type " + dataObj.hgOperation + " is not valid"

    # check all old areas
    for oldArea in dataObj.oldAreas

      # check if area is given
      if not oldArea.area
        return console.error "The associated Area could not been found"

      # check if name is given
      if not oldArea.name
        return console.error "The associated AreaName could not been found"

      # check if territory is given
      if not oldArea.territory
        return console.error "The associated AreaTerritory could not been found"

    # check all new areas
    for newArea in dataObj.newAreas

      # check if area is given
      if not newArea.area
        return console.error "The associated Area could not been found"

      # check if name is given
      if not newArea.name
        return console.error "The associated AreaName could not been found"

      # check if territory is given
      if not newArea.territory
        return console.error "The associated AreaTerritory could not been found"

    # check if operation has necessary new/old area name/territory
    switch dataObj.operation

      when 'UNI'
        if not (
            (dataObj.oldAreas.length >= 1)  and
            (dataObj.newAreas.length == 1)  and
            (not dataObj.updateArea)
          )
          return console.error "The UNI operation does not have the expected data provided"

      when 'INC'
        if not (
            (dataObj.oldAreas.length >= 1)  and
            (dataObj.newAreas.length == 0)  and
            (dataObj.updateArea)
          )
          return console.error "The INC operation does not have the expected data provided"

      when 'SEP'
        if not (
            (dataObj.oldAreas.length == 1)  and
            (dataObj.newAreas.length >= 2)  and
            (not dataObj.updateArea)
          )
          return console.error "The SEP operation does not have the expected data provided"

      when 'SEC'
        if not (
            (dataObj.oldAreas.length == 0)  and
            (dataObj.newAreas.length >= 1)  and
            (dataObj.updateArea)
          )
          return console.error "The SEC operation does not have the expected data provided"

      when 'NCH'
        if not (
            (dataObj.oldAreas.length == 0)  and
            (dataObj.newAreas.length == 0)  and
            (dataObj.updateArea)
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
      # console.log xhr.responseText