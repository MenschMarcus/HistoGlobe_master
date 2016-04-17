window.HG ?= {}

# ==============================================================================
# Step 3 in Edit Operation Workflow: define name of newly created area
# TODO: set names in all languages
# ==============================================================================

class HG.EditOperationStep.CreateNewNames extends HG.EditOperationStep


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, direction) ->

    # inherit functionality from base class
    super @_hgInstance, direction

    # skip operations without user input
    return @finish() if not @_stepData.userInput

    # include
    @_geometryOperator = new HG.GeometryOperator


    ### SETUP OPERATION ###

    # forward: start at the first area
    if direction is 1
      @_areaIdx = -1
    # backward: start at the last area
    else
      @_areaIdx = @_stepData.inData.areas.length

    @_makeNewName direction



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _makeNewName: (direction) ->

    # abort prev Step -> first name and backwards
    return @abort()   if (@_areaIdx is 0) and (direction is -1)

    # go to next/previous area
    @_areaIdx += direction

    # get area to work with
    @_currArea =      @_stepData.inData.areas[@_areaIdx]
    @_currName =      @_stepData.inData.areaNames[@_areaIdx]
    @_currTerritory = @_stepData.inData.areaTerritories[@_areaIdx]

    # initial values for NewNameTool
    initData = {
      shortName:            @_currName?.shortName
      formalName:           @_currName?.formalName
      representativePoint:  @_currTerritory.representativePoint
    }
    # override with temporary data from last time, if it is available
    initData = $.extend {}, initData, @_stepData.tempData[@_areaIdx]

    # remove the name from the area
    if @_currArea.name
      @_currArea.name = null
      @_currArea.handle.update()

    # set up NewNameTool to set name and position of area interactively
    newNameTool = new HG.NewNameTool @_hgInstance, initData


    # --------------------------------------------------------------------------
    ### LISTEN TO USER INPUT ###

    newNameTool.onSubmit @, (newData) =>

      # do not reuse @_curr variables, because they are references
      # => avoids overriding incoming data
      newArea       = @_currArea
      newName       = @_currName
      newTerritory  = @_currTerritory

      # temprrarily save new data so it can be restores on undo
      @_stepData.tempData.push newData

      # decision: what has changed?
      shortNameHasChanged =   newData.shortName.localeCompare(newName?.shortName) isnt 0
      formalNameHasChanged =  newData.formalName.localeCompare(newName?.formalName) isnt 0
      reprPointHasChanged =   not @_geometryOperator.areEqual(newData.representativePoint, newTerritory.representativePoint)


      # TODO: create new identity if formalNameHasChanged

      # ------------------------------------------------------------------------
      if @_operationId is 'NCH'                         # name change operation

        # had no NewTerritoryStep => new Area and AreaHandle to be created here
        newArea = new HG.Area @_hgInstance.editOperation.getRandomId()
        newArea.handle = new HG.AreaHandle @_hgInstance, newArea

        # link Area <-> AreaTerritory (use the current one)
        newArea.territory = newTerritory
        newTerritory.area = newArea

        # show current status
        newArea.handle.show()

      # ------------------------------------------------------------------------
                                                      # for all other operations
      # update AreaTerritory if representative point has changed
      if reprPointHasChanged
        newTerritory.representativePoint = newData.representativePoint
        newTerritory.area.handle.update()

      # create new AreaName if name has changed
      if shortNameHasChanged or formalNameHasChanged

        newName = new HG.AreaName {
          id:         @_hgInstance.editOperation.getRandomId()
          shortName:  newData.shortName
          formalName: newData.formalName
        }

        # link Area <-> AreaName
        newArea.name = newName
        newName.area = newArea

        # update view
        newArea.handle.update()

      # add to operation workflow
      @_stepData.outData.areas[@_areaIdx] =           newArea
      @_stepData.outData.areaNames[@_areaIdx] =       newName
      @_stepData.outData.areaTerritories[@_areaIdx] = newTerritory

      # define when it is finished
      return @finish() if @_areaIdx is @_stepData.inData.areas.length-1

      # make action reversible
      @_undoManager.add {
        undo: =>
          # restore old area
          oldTerritory =  @_stepData.inData.areaTerritories[@_areaIdx]
          oldName =       @_stepData.inData.areaNames[@_areaIdx]
          oldArea =       @_stepData.inData.areas[@_areaIdx]

          # reset old properties
          if oldName then       oldArea.name = oldName
          if oldTerritory then  oldArea.territory = oldTerritory

          # update view
          oldArea.handle.update()

          # go to previous name
          @_cleanup()
          @_makeNewName -1
      }

      # go to next name
      @_cleanup()
      @_makeNewName 1


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP OPERATION ###
    @_hgInstance.newNameTool?.destroy()
    @_hgInstance.newNameTool = null

    ### RESTORE NAME OF FIRST AREA ###
    # if it has not been updated yet
    # this is not covered by any undo action, because before the new name was
    # not submitted from newNameTool, there is no undo event in the undoManager
    # area = @_stepData.tempAreas[@_areaIdx]
    # if area.nameRemoved and not area.nameUpdated
    #   @notifyEditMode 'onAddAreaName', area.id, area.shortName, area.formalName
    # WTF ?!?