window.HG ?= {}

# ==============================================================================
# Step 1 in Edit Operation Workflow: Select areas on the map subject to change
# interaction with AreasOnMap module
# ==============================================================================

class HG.SelectOldAreasStep extends HG.EditOperationStep

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, @_stepData, isForward) ->

    # inherit functionality from base class
    super @_hgInstance, @_stepData

    # skip steps without user input
    return @finish() if not @_stepData.userInput

    # get external modules
    @_workflowWindow = @_hgInstance.workflowWindow
    @_areasOnMap = @_hgInstance.areasOnMap


    ### SETUP OPERATION ###

    ## for both forward and backward step
    # tell AreasOnMap to start selecting maximal X number of areas
    @_areasOnMap.startAreaSelection @_stepData.number.max

    ## for forward step
    if isForward

      # add already selected areas to list
      @_initArea = null
      if @_areasOnMap.getSelectedAreas()[0]
        @_initArea = @_areasOnMap.getSelectedAreas()[0]
        @_stepData.outData.selectedAreas.push @_initArea

    ## for backward step
    else

      # put all previously selected areas back on the map
      for area in @_stepData.outData.selectedAreas
        area.select()
        @_areasOnMap.updateArea area


    ### REACT ON USER INPUT ###
    # listen to area (de)selection from AreasOnMap

    @_areasOnMap.onSelectArea @, (area) =>
      if @_stepData.outData.selectedAreas.indexOf area is -1
        @_stepData.outData.selectedAreas.push area

      # is step complete?
      if @_stepData.outData.selectedAreas.length >= @_stepData.number.min
        @_workflowWindow.stepComplete()

    @_areasOnMap.onDeselectArea @, (area) =>
      if @_stepData.outData.selectedAreas.indexOf area isnt -1
        # remove Area from array
        @_stepData.outData.selectedAreas.splice (@_stepData.outData.selectedAreas.indexOf area), 1

      # is step incomplete?
      if @_stepData.outData.selectedAreas.length < @_stepData.number.min
        @_workflowWindow.stepIncomplete()


    # TODO: problem still there? shouldn't be actually... if so, delete this snippet
    # # problem: listens to callback multiple times if function is called multiple times
    # # solution: ensure listen to callback only once
    # if not @_activeCallbacks.onSelectArea

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  _cleanup: () ->

    ### CLEANUP OPERATION ###
    if @_stepData.userInput

      # deselect selected areas (except for the initially selected one)
      for area in @_stepData.outData.selectedAreas
        area.deselect() unless @_initArea? and area.getId() is @_initArea.getId()
        @_areasOnMap.updateArea area

      # tell areas on map to stop select areas
      @_areasOnMap.finishAreaSelection()
