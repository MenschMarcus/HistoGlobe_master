window.HG ?= {}

# ==============================================================================
# Step 4 in Edit Operation Workflow: Add change to a Hivent
# ==============================================================================

class HG.EditOperationStep.AddChange extends HG.EditOperationStep

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, @_stepData, @_operationDescription) ->

    # inherit functionality from base class
    super @_hgInstance, @_stepData

    # get external modules
    workflowWindow = @_hgInstance.workflowWindow


    ### SETUP OPERATION ###

    # hivent box: select existing or create new hivent

    @_hiventBox = new HG.NewHiventBox @_hgInstance, @_stepData, @_operationDescription

    ### INTERACTION ###
    # tell workflow window to change to the finish button
    @_hiventBox.onReady @, () ->
      workflowWindow.setupFinishButton()

    @_hiventBox.onUnready @, () ->
      workflowWindow.cleanupFinishButton()



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

    @_hiventBox.destroy()

    @notifyEditMode 'onFinishAreaEdit'
