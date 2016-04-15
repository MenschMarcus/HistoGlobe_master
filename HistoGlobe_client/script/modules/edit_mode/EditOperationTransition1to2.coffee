window.HG ?= {}

# ==============================================================================
# Transition from SelectOldAreas to CreateNewTerritories
# ==============================================================================

class HG.EditOperationTransition1to2 extends HG.EditOperationTransition

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, direction) ->

    super @_hgInstance, direction

    # ==========================================================================
    if direction is 1                  ## SelectOldAreas -> CreateNewGeometry ##

      ### SETUP OPERATION ###



    # ==========================================================================
    else                               ## SelectOldAreas <- CreateNewGeometry ##

      # put all previously selected areas back on the map
      for area in @_stepData.outData.selectedAreas
        @notifyEditMode 'onEndEditArea', area
        @notifyEditMode 'onSelectArea', area

      ### CLEANUP OPERATION ###


    # ==========================================================================

    @_makeStep direction