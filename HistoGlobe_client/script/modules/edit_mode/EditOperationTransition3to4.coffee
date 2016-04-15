window.HG ?= {}

# ==============================================================================
# Transition from CreateNewNames to AddChange
# ==============================================================================

class HG.EditOperationTransition3to4 extends HG.EditOperationTransition

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, direction) ->

    super @_hgInstance, direction

    # ==========================================================================
    if direction is 1                           ## CreateNewName -> AddChange ##

      ### SETUP OPERATION ###



    # ==========================================================================
    else                                        ## CreateNewName <- AddChange ##

      ### CLEANUP OPERATION ###


    # ==========================================================================

    @_makeStep direction