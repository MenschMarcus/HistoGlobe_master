window.HG ?= {}

# ==============================================================================
# loads initial Areas and Hivents from the server and creates their links
# to each other via start/end operations
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
        # so they can be linked to HiventOperations later
        areaNames = []
        for areaNameData in dataObj.area_names
          areaNameData = @_areaNameToClient areaNameData
          areaName = new HG.AreaName areaNameData
          areaName.area = areaNameData.area
          areaNames.push areaName

        areaTerritories = []
        for areaTerritoryData in dataObj.area_territories
          areaTerritoryData = @_areaTerritoryToClient areaTerritoryData
          areaTerritory = new HG.AreaTerritory areaTerritoryData
          areaTerritory.area = areaTerritoryData.area
          areaTerritories.push areaTerritory

        # create Hivents
        for hiventData in dataObj.hivents
          hivent = new HG.Hivent @_hiventToClient hiventData

          # create EditOperations
          for editOperationData in hiventData.edit_operations
            editOperationData = @_editOperationToClient editOperationData
            editOperationData = @_validateEditOperation editOperationData
            editOperation = new HG.EditOperation editOperationData

            # create HiventOperations
            for hiventOperationInData in editOperationData.hiventOperations
              hiventOperationInData = @_hiventOperationToClient hiventOperationInData
              hiventOperationInData = @_validateHiventOperation hiventOperationInData

              # assemble HiventOperation and link to Area(Name/Territory)
              hiventOperationOutData = {
                id:           hiventOperationInData.id
                operation:  hiventOperationInData.operation
                oldAreas:     []
                newAreas:     []
                updateArea:   null
              }

              for oldArea in hiventOperationInData.oldAreas
                hiventOperationOutData.oldAreas.push {
                  area:       areas.find (obj) -> obj.id is oldArea.area
                  name:       areaNames.find (obj) -> obj.id is oldArea.name
                  territory:  areaTerritories.find (obj) -> obj.id is oldArea.territory
                }

              for newArea in hiventOperationInData.newAreas
                hiventOperationOutData.newAreas.push {
                  area:       areas.find (obj) -> obj.id is newArea.area
                  name:       areaNames.find (obj) -> obj.id is newArea.name
                  territory:  areaTerritories.find (obj) -> obj.id is newArea.territory
                }

              if hiventOperationInData.updateArea
                updArea = hiventOperationInData.updateArea
                hiventOperationOutData.updateArea = {
                  area:         areas.find (obj) -> obj.id is updArea.area
                  oldName:      areaNames.find (obj) -> obj.id is updArea.old_name
                  newName:      areaNames.find (obj) -> obj.id is updArea.new_name
                  oldTerritory: areaTerritories.find (obj) -> obj.id is updArea.old_territory
                  newTerritory: areaTerritories.find (obj) -> obj.id is updArea.new_territory
                }

              hiventOperation = new HG.HiventOperation hiventOperationOutData

              # link EditOperation <-> HiventOperation
              hiventOperation.editOperation = editOperation
              editOperation.hiventOperations.push hiventOperation

            # link Hivent <-> EditOperation
            editOperation.hivent = hivent
            hivent.editOperations.push editOperation

          # finalize handle
          hiventHandle = new HG.HiventHandle @_hgInstance, hivent
          hivent.handle = hiventHandle
          @_hgInstance.hiventController.addHiventHandle hiventHandle

        # DONE!
        @notifyAll 'onFinishLoadingInitData'

      error: @_errorCallback


  # ============================================================================
  # Save the outcome of an historical Operation to the server: the Hivent,
  # its associated EditOperation and their HiventOperations, including their
  # associated Areas, AreaNames and AreaTerritories.
  # All objects have temporary IDs, the server will create real IDs and return
  # them. This function also updates the IDs.
  # ============================================================================

  saveHistoricalOperation: (hiventData, editOperation) ->

    # request data sent to the server

    request = {
      hivent:               null
      hivent_is_new:        yes
      edit_operation:       {}
      new_areas:            []
      new_area_names:       []
      new_area_territories: []
    }

    # assemble relevant data for the request, resolving the circular double-link
    # structure to a one-directional hierarchical structure:
    # Hivent -> EditOperation -> [HiventOperation] --> Area
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


    ## EditOperation: omit Hivent (link upward)
    request.edit_operation = {
      id:           editOperation.id
      operation:    editOperation.operation
      hivent_operations: []  # store only ids, so they can be associated
    }

    ## HiventOperations: omit EditOperation (link upward), save only ids of Areas
    for hiventOperation in editOperation.hiventOperations
      request.edit_operation.hivent_operations.push {
        id:                   hiventOperation.id
        operation:            hiventOperation.operation
        area:                 hiventOperation.area.id
        old_area_name:        hiventOperation.oldAreaName?.id
        old_area_territory:   hiventOperation.oldAreaTerritory?.id
        new_area_name:        hiventOperation.newAreaName?.id
        new_area_territory:   hiventOperation.newAreaTerritory?.id
      }

      ## new Area is part of each ADD operation
      if hiventOperation.operation is 'ADD'
        request.new_areas.push {
          id:   hiventOperation.area.id
        }

      ## new AreaName is part of each ADD and NCH operation
      if hiventOperation.operation is 'ADD' or hiventOperation.operation is 'NCH'
        request.new_area_names.push {
          id:           hiventOperation.newAreaName.id
          short_name:   hiventOperation.newAreaName.shortName
          formal_name:  hiventOperation.newAreaName.formalName
        }

      ## new AreaTerritory is part of each ADD and TCH operation
      if hiventOperation.operation is 'ADD' or hiventOperation.operation is 'TCH'
        request.new_area_territories.push {
          id:                   hiventOperation.newAreaTerritory.id
          geometry:             hiventOperation.newAreaTerritory.geometry.wkt()
          representative_point: hiventOperation.newAreaTerritory.representativePoint.wkt()
        }

      # make hivent and editOperation accessible in success callback
      @_hivent =            hivent
      @_editOperation =  editOperation


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


          ## EditOperation
          @_editOperation.id = dataObj.edit_operation_id

          # Hivent <-> EditOperation
          hivent.editOperations.push @_editOperation
          @_editOperation.hivent = hivent


          ## HiventOperations
          for hiventOperation in @_editOperation.hiventOperations

            # find associated hiventOperationData id in response data
            for hivent_operation in dataObj.hivent_operations
              if hiventOperation.id is hivent_operation.old_id

                # update id
                hiventOperation.id = hivent_operation.new_id

                ## Area
                hiventOperation.area.id = hivent_operation.area_id

                # HiventOperation <- Area
                switch hiventOperation.operation
                  when 'ADD' then         hiventOperation.area.startChange =       hiventOperation
                  when 'DEL' then         hiventOperation.area.endChange =         hiventOperation
                  when 'TCH', 'NCH' then  hiventOperation.area.updateChanges.push  hiventOperation

                ## AreaName
                if hiventOperation.oldAreaName
                  # id is already up to data
                  # HiventOperation <- AreaName
                  hiventOperation.oldAreaName.endChange = hiventOperation

                if hiventOperation.newAreaName
                  # update id
                  hiventOperation.newAreaName.id = hivent_operation.new_area_name_id
                  # HiventOperation <- AreaName
                  hiventOperation.newAreaName.startChange = hiventOperation

                ## AreaTerritory
                if hiventOperation.oldAreaTerritory
                  # id is already up to data
                  # HiventOperation <- AreaTerritory
                  hiventOperation.oldAreaTerritory.endChange = hiventOperation

                if hiventOperation.newAreaTerritory
                  # update id
                  hiventOperation.newAreaTerritory.id = hivent_operation.new_area_territory_id
                  # HiventOperation <- AreaTerritory
                  hiventOperation.newAreaTerritory.startChange = hiventOperation

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
  _editOperationToClient: (dataObj) ->
    {
      id:             parseInt dataObj.id
      operation:      dataObj.operation
      hivent:         dataObj.hivent
      hiventOperations:    dataObj.hivent_operations  # not changed, yet
    }

  # ----------------------------------------------------------------------------
  _editOperationToServer: (dataObj) ->
    # TODO if necessary

  # ----------------------------------------------------------------------------
  _hiventOperationToClient: (dataObj, areaNames, areaTerritories) ->
    {
      id:               parseInt dataObj.id
      editOperation:    dataObj.edit_operation # not changed, yet
      operation:        dataObj.operation
      oldAreas:         dataObj.old_areas
      newAreas:         dataObj.new_areas
      updateArea:       dataObj.update_area
    }

  # ----------------------------------------------------------------------------
  _hiventOperationToServer: (dataObj) ->
    # TODO if necessary


  # ============================================================================
  # validation for all data in EditOperation
  # ensures that EditOperation can correctly be executed
  # ============================================================================

  _validateEditOperation: (dataObj) ->

    # check if id is a number
    if isNaN(dataObj.id)
      return console.error "The id is not valid"

    # check if operation type is correct
    if ['CRE','MRG','DIS','CHB','REN','CES'].indexOf(dataObj.operation) is -1
      return console.error "The operation type " + dataObj.operation + " is not valid"

    # got all the way here? Then everything is good :)
    return dataObj


  # ============================================================================
  # validation for all data in HiventOperation
  # ensures that HiventOperation can correctly be executed
  # ============================================================================

  _validateHiventOperation: (dataObj) ->

    # check if id is a number
    dataObj.id = parseInt dataObj.id
    if isNaN(dataObj.id)
      return console.error "The id is not valid"

    # check if operation type is correct
    if ['UNI','INC','SEP','SEC','NCH'].indexOf(dataObj.operation) is -1
      return console.error "The operation type " + dataObj.operation + " is not valid"

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