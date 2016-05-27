window.HG ?= {}

# ==============================================================================
# loads initial areas and hivents from the server and creates their links
# to each other via start/end hivents and AreaChange
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

        # temporary object array for all data regarding AreaChanges
        tempAreaChanges = new HG.ObjectArray

        # universe Area
        universe = new HG.Area {
          id:       -1
          universe: yes
        }
        universeTerritory = {}  # empty object, to prevent problems
        universe.territory = universeTerritory

        # (@_hgInstance.areaController.getAreaHandle dataObj.area).getArea()

        # create AreaNames
        # and store them in areaChange objArr so they can be linked to AreaChange later
        for anData in dataObj.area_names
          anData = @_areaNameToClient anData
          areaName = new HG.AreaName anData

          # put start change into temporary array for area changes
          # to connect them together later
          # check if area change already exists in list
          currChange = tempAreaChanges.getById anData.startChange
          if not currChange
            tempAreaChanges.push {
              id:   anData.startChange
              areas: new HG.ObjectArray
            }
            currChange = tempAreaChanges.getLast()

          # check if area in areaName already exists in list
          areaInChange = currChange.areas.getById anData.area
          # finally put areaName and area in objArr
          if areaInChange
            areaInChange.newName = areaName
          else
            currChange.areas.push {
              id:           anData.area
              oldName:      null
              newName:      areaName
              oldTerritory: null
              newTerritory: null
            }

          # put end change into temporary array for area changes
          # to connect them together later
          if anData.endChange
            # check if area change already exists in list
            currChange = tempAreaChanges.getById anData.endChange
            if not currChange
              tempAreaChanges.push {
                id:   anData.startChange
                areas: new HG.ObjectArray
              }
              currChange = tempAreaChanges.getLast()

            # check if area in areaName already exists in list
            areaInChange = currChange.areas.getById anData.area
            # finally put areaName and area in objArr
            if areaInChange
              areaInChange.oldName = areaName
            else
              currChange.areas.push {
                id:           anData.area
                oldName:      areaName
                newName:      null
                oldTerritory: null
                newTerritory: null
              }

        # create AreaTerritories
        # and store them in areaChange objArr so they can be linked to AreaChange later
        for atData in dataObj.area_territories
          atData = @_areaTerritoryToClient atData
          areaTerritory = new HG.AreaTerritory atData

          # put start change into temporary array for area changes
          # to connect them together later
          # check if area change already exists in list
          currChange = tempAreaChanges.getById atData.startChange
          if not currChange
            tempAreaChanges.push {
              id:   atData.startChange
              areas: new HG.ObjectArray
            }
            currChange = tempAreaChanges.getLast()

          # check if area in areaTerritory already exists in list
          areaInChange = currChange.areas.getById atData.area
          # finally put areaTerritory and area in objArr
          if areaInChange
            areaInChange.newTerritory = areaTerritory
          else
            currChange.areas.push {
              id:             atData.area
              oldName:        null
              newName:        null
              oldTerritory:   null
              newTerritory:   areaTerritory
            }

          # put end change into temporary array for area changes
          # to connect them together later
          if atData.endChange
            # check if area change already exists in list
            currChange = tempAreaChanges.getById atData.endChange
            if not currChange
              tempAreaChanges.push {
                id:   anData.startChange
                areas: new HG.ObjectArray
              }
              currChange = tempAreaChanges.getLast()

            # check if area in areaTerritory already exists in list
            areaInChange = currChange.areas.getById atData.area
            # finally put areaTerritory and area in objArr
            if areaInChange
              areaInChange.oldTerritory = areaTerritory
            else
              currChange.areas.push {
                id:           atData.area
                oldName:      null
                newName:      null
                oldTerritory: areaTerritory
                newTerritory: null
              }

        # create Areas + handles
        for areaData in dataObj.areas
          areaData = @_areaToClient areaData
          area = new HG.Area areaData
          areaHandle = new HG.AreaHandle @_hgInstance, area
          area.handle = areaHandle

          # put into tempAreaChanges and
          # connect with AreaName and AreaTerritory
          tempAreaChanges.foreach (areaChange) =>
            areas = areaChange.areas
            areas.foreach (areaData) =>
              if areaData.id = area.id
                areaData.area = area
                areaData.oldName?.area = area
                areaData.newName?.area = area
                areaData.oldTerritory?.area = area
                areaData.newTerritory?.area = area

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
              acData = @_areaChangeToClient acData
              acData = @_validateAreaChange acData

              # get areas for AreaChange
              acAreas = (tempAreaChanges.getById acData.id).areas

              # create AreaChange
              areaChange = null

              switch acData.operation

                # when 'UNI'  # unification
                #   areaChange = new HG.AreaChange.UNI(

                #     )


                # when 'INC'  # incorporation
                #   areaChange = new HG.AreaChange.INC(

                #     )


                # when 'SEP'  # separation
                #   areaChange = new HG.AreaChange.SEP(

                #    )


                when 'SEC'  # secession

                  # hack: in 'CRE' operation, 'SEC' = secession from the universe
                  # universe is omitted in this prototype
                  if historicalChange.operation is 'CRE'
                    preserveArea = universe
                    oldTerritory = universeTerritory
                  else
                    console.log acAreas

                  newAreas = []
                  acAreas.foreach (areaData) ->
                    newAreas.push areaData.area

                  areaChange = new HG.AreaChange.SEC(
                      acData.id, preserveArea, oldTerritory, newAreas
                    )

                  console.log areaChange


                # when 'NCH'  # name change
                #   areaChange = new HG.AreaChange.NCH(

                #     )


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

  # ----------------------------------------------------------------------------
  _areaToServer: (dataObj) ->
    {
      id:           parseInt dataObj.id
      universe:     dataObj.universe
      start_change: dataObj.startChange?.id
      end_change:   dataObj.endChange?.id
    }

  # ----------------------------------------------------------------------------
  _areaToClient: (dataObj) ->
    {
      id:           parseInt dataObj.id
      universe:     dataObj.universe
      startChange:  dataObj.start_change  # only id!
      endChange:    dataObj.end_change    # only id!
    }

  # ----------------------------------------------------------------------------
  _areaNameToServer: (dataObj) ->
    {
      id:           parseInt dataObj.id
      short_name:   dataObj.shortName
      formal_name:  dataObj.formalName
      area:         dataObj.area?.id
      start_change: dataObj.startChange?.id
      end_change:   dataObj.endChange?.id
    }

  # ----------------------------------------------------------------------------
  _areaNameToClient: (dataObj) ->
    {
      id:           parseInt dataObj.id
      shortName:    dataObj.short_name
      formalName:   dataObj.formal_name
      area:         dataObj.area          # only id!
      startChange:  dataObj.start_change  # only id!
      endChange:    dataObj.end_change    # only id!
    }

  # ----------------------------------------------------------------------------
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
      area:                 dataObj.area          # only id!
      startChange:          dataObj.start_change  # only id!
      endChange:            dataObj.end_change    # only id!
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
      id:           parseInt dataObj.id
      operation:    dataObj.edit_operation
      hivent:       dataObj.hivent
      areaChanges:  dataObj.area_changes
    }

  # ----------------------------------------------------------------------------
  _historicalChangeToServer: (dataObj) ->
    # TODO if necessary

  # ----------------------------------------------------------------------------
  _areaChangeToClient: (dataObj) ->
    {
      id:               parseInt dataObj.id
      historicalChange: dataObj.historical_change # not changed, yet
      operation:        dataObj.hg_operation
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
    if ['CRE','MRG','DIS','CHB','REN','CES'].indexOf(dataObj.operation) is -1
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
    if ['UNI','INC','SEP','SEC','NCH'].indexOf(dataObj.operation) is -1
      return console.error "The operation type " + dataObj.operation + " is not valid"

    # got all the way here? Then everything is good :)
    return dataObj


  # ==========================================================================
  # error callback
  # ==========================================================================

  _errorCallback: (xhr, status, errorThrown) ->
    console.log xhr
    console.log status
    console.log errorThrown