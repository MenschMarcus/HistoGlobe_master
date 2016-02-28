window.HG ?= {}

# ==============================================================================
# Step 4 in Edit Operation Workflow: Add change to a Hivent
# ==============================================================================

class HG.AddChangeStep extends HG.EditOperationStep

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, @_stepData) ->

    # inherit functionality from base class
    super @_hgInstance, @_stepData

    # get external modules
    @_workflowWindow = @_hgInstance.workflowWindow
    @_areasOnMap = @_hgInstance.areasOnMap


    ### SETUP OPERATION ###

    # hivent box: select existing or create new hivent

    hiventBox = new HG.NewHiventBox @_hgInstance, @_stepData


    # setup new hivent
    # @_stepData.outData.hiventInfo = {
    #   name          : ""
    #   date          : "20th century"
    #   location      : "Weimar"
    #   lng           : 0
    #   lat           : 0
    #   description   : ""
    #   link          : ""
    # }

      # send to operation and finish ?!?

    ## that would be the nice way to do it, directly in HistoGlobe
    ## but I am going to go the easy way :-)
    # builder = new HG.HiventBuilder
    # hivent = builder._createHivent hiventData
    # hiventHandle = new HG.HiventHandle hivent

    # @_popover = new HG.HiventInfoPopover(
    #     hiventHandle,
    #     @_hgInstance._top_area,
    #     @_hgInstance,
    #     1,
    #     yes
    #   )

    # $('.guiPopoverTitle')[0].contentEditable = true
    # $('.hivent-content')[0].contentEditable = true

    # @_popover.show new HG.Vector $('body').width()-237, 380


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _cleanup: () ->

    hiventBox.destroy()
    @_areasOnMap.finishAreaEdit() if @_isForward

    ### CLEANUP OPERATION ###
