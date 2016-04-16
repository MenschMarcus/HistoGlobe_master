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

    @_finish = no

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

    # finish criterion: next Step
    return @makeTransition 1  if @_finish
    # finish criterion: prev Step -> first name and backwards
    return @makeTransition -1 if (@_areaIdx is 0) and (direction is -1)

    # go to next/previous area
    @_areaIdx += direction

    # get area to work with
    @_currArea = @_stepData.inData.areas[@_areaIdx]

    # TODO: deep copy?
    # initial values for NewNameTool
    @_initData = {
      shortName:  null
      formalName: null
      geometry:   @_currArea.territory.geometry
      reprPoint:  @_currArea.territory.representativePoint
    }

    # for name change operation
    if @_operationId is 'NCH'
      @_currArea.handle.hideName()  # TODO
      # save name as initial value for NewNameTool
      @_initData.shortName = @_currArea.name.shortName
      @_initData.formalName = @_currArea.name.formalName

    # set up NewNameTool to set name and position of area interactively
    newNameTool = new HG.NewNameTool @_hgInstance, @_initData


    ### LISTEN TO USER INPUT ###

    newNameTool.onSubmit @, (newShortName, newFormalName, newReprPoint) =>

      # decision: what has changed?
      shortNameHasChanged = newShortName.localeCompare(@_initData.shortName) isnt 0
      formalNameHasChanged = newFormalName.localeCompare(@_initData.formalName) isnt 0
      reprPointHasChanged = not @_geometryOperator.areEqual newReprPoint, @_initData.reprPoint

      # create new Area for special operation(s)
      newArea = @_currArea
      if @_operationId is 'NCH'
        newArea = new HG.Area @_hgInstance.editOperation.getRandomId()
        newHandle = new HG.AreaHandle @_hgInstance, newArea
        newArea.handle = newHandle

      # create new AreaName if name has changed
      if shortNameHasChanged or formalNameHasChanged
        newName = new HG.AreaName {
          id:         @_hgInstance.editOperation.getRandomId()
          shortName:  newShortName
          formalName: newFormalName
        }
        # link Area <-> AreaName
        newArea.name = newName
        newName.area = newArea
        # update area model and view
        newArea.handle.updateName()

      # create new AreaTerritory if representative point has changed
      if reprPointHasChanged
        newTerritory = new HG.AreaTerritory {
          id:                   @_hgInstance.editOperation.getRandomId()
          geometry:             @_initData.geometry
          representativePoint:  newReprPoint
        }
        # link Area <-> AreaTerritory
        newArea.territory = newTerritory
        newTerritory.area = newArea
        # update area model and view
        newArea.handle.updateTerritory()

      # add to operation workflow
      @_stepData.outData.areas.push           newArea
      @_stepData.outData.areaNames.push       newArea.name
      @_stepData.outData.areaTerritories.push newArea.territory

      console.log @_hgInstance.editOperation.operation

      # make action reversible
      @_undoManager.add {
        undo: =>
          # # get area
          # area = 42
          # # restore old name
          # if area.nameRemoved
          #   @notifyEditMode 'onAddAreaName', area.id, area.shortName, area.formalName
          # else
          #   @notifyEditMode 'onUpdateAreaName', area.id, area.shortName, area.formalName
          # @notifyEditMode 'onUpdateAreaRepresentativePoint', area.id, area.reprPoint

          # # go to previous area
          # @_cleanup()
          # @_makeNewName -1
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
    area = @_stepData.tempAreas[@_areaIdx]
    if area.nameRemoved and not area.nameUpdated
      @notifyEditMode 'onAddAreaName', area.id, area.shortName, area.formalName