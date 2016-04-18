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

    # get all name suggestions that are possible to autocomplete into
    @_nameSuggestions = []    # all possible names (HG.AreaName)
    defaultName = null        # name that is displayed as default to the user

    switch @_operationId

      # for UNI/INC and SEP/SEC: make it possible to autocomplete to the name of
      # any selected area from the first step => make them suggestions
      when 'UNI', 'INC', 'SEP', 'SEC'
        for areaName in @_hgInstance.editOperation.operation.steps[1].outData.areaNames
          @_nameSuggestions.push areaName

      # for NCH and TCH/BCH: set the current name of the area as default value
      # to work immediately on it or just use it
      when 'NCH', 'TCH', 'BCH'
        @_nameSuggestions.push @_currName
        defaultName = {
          shortName:  @_currName.shortName
          formalName: @_currName.formalName
        }

      # for CRE: no old area => no possible suggestion => ignore
      # for DES: no new area => ignore


    # initial values for NewNameTool
    tempData = {
      nameSuggestions:    []
      name:               defaultName
      oldPoint:           @_currTerritory.representativePoint
      newPoint:           null
    }

    # do not hand the HG.AreaName into NewNameTool, but only the name strings
    # => used nameAuggestion will be determined later by string comparison
    for nameSuggestion in @_nameSuggestions
      tempData.nameSuggestions.push {
        shortName:  nameSuggestion.shortName
        formalName: nameSuggestion.formalName
      }

    # override with temporary data from last time, if it is available
    tempData = $.extend {}, tempData, @_stepData.tempData[@_areaIdx]

    # remove the name from the area
    if @_currArea.name
      @_currArea.name = null
      @_currArea.handle.update()

    # set up NewNameTool to set name and position of area interactively
    newNameTool = new HG.NewNameTool @_hgInstance, tempData


    # --------------------------------------------------------------------------
    ### LISTEN TO USER INPUT ###

    newNameTool.onSubmit @, (newData) =>

      # do not reuse @_curr variables, because they are references
      # => avoids overriding incoming data
      newArea       = @_currArea
      newName       = @_currName
      newTerritory  = @_currTerritory

      # temporarily save new data so it can be restores on undo
      @_stepData.tempData[@_areaIdx] = newData

      # update AreaTerritory (representative point has always changed, at least slightly)
      newTerritory.representativePoint = newData.newPoint
      newTerritory.area.handle.update()

      # create new AreaName if name has changed
      if  (newData.name.shortName.localeCompare(newName?.shortName) isnt 0) or
          (newData.name.formalName.localeCompare(newName?.formalName) isnt 0)

        newName = new HG.AreaName {
          id:         @_hgInstance.editOperation.getRandomId()
          shortName:  newData.name.shortName
          formalName: newData.name.formalName
        }

      # link Area <-> AreaName
      newArea.name = newName
      newName.area = newArea

      # update view (even if name has not changed, to restore it on the map)
      newArea.handle.update()

      # handle special case in UNI or SEP operation:
      # if the formal name of one of the selected areas is the same than
      # one of the new areas, these two areas keep have the same identity
      # => change UNI -> INC resp. SEP -> SEC operation


      # add to operation workflow
      @_stepData.outData.areas[@_areaIdx] =           newArea
      @_stepData.outData.areaNames[@_areaIdx] =       newName
      @_stepData.outData.areaTerritories[@_areaIdx] = newTerritory


      # make action reversible
      @_undoManager.add {
        undo: =>
          # restore old area
          oldTerritory =  @_stepData.inData.areaTerritories[@_areaIdx]
          oldName =       @_stepData.inData.areaNames[@_areaIdx]
          oldArea =       @_stepData.inData.areas[@_areaIdx]

          # reset old properties
          if oldName
            oldArea.name = oldName
          if oldTerritory
            oldTerritory.representativePoint = @_stepData.tempData[@_areaIdx].oldPoint
            oldArea.territory = oldTerritory

          # update view
          oldArea.handle.update()

          # go to previous name
          @_cleanup()
          @_makeNewName -1
      }

      # define when it is finished
      return @finish() if @_areaIdx is @_stepData.inData.areas.length-1

      # go to next name
      @_cleanup()
      @_makeNewName 1


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP OPERATION ###
    @_hgInstance.newNameTool?.destroy()
    @_hgInstance.newNameTool = null