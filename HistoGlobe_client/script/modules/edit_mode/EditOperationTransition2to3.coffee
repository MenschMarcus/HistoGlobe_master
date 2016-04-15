window.HG ?= {}

# ==============================================================================
# Transition from CreateNewTerritories to CreateNewNames
# ==============================================================================

class HG.EditOperationTransition2to3 extends HG.EditOperationTransition

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, direction) ->

    super @_hgInstance, direction

    # ==========================================================================
    if direction is 1                  ## CreateNewGeometry -> CreateNewName ##

      ### SETUP OPERATION ###



    # ==========================================================================
    else                               ## CreateNewGeometry <- CreateNewName ##

      ### CLEANUP OPERATION ###


    # ==========================================================================

    @_makeStep direction