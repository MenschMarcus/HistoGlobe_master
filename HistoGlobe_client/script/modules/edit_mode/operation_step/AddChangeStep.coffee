window.HG ?= {}

# ==============================================================================
# Step 4 in Edit Operation Workflow: Add change to a Hivent
# ==============================================================================

class HG.AddChangeStep extends HG.EditOperationStep

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, @_stepData, @_isForward) ->

    # inherit functionality from base class
    super @_hgInstance, @_stepData

    # get external modules
    @_workflowWindow = @_hgInstance.workflowWindow
    @_areasOnMap = @_hgInstance.areasOnMap

    ### SETUP OPERATION ###

    # setup new hivent
    hiventData = {
      id            : 'NEW'
      name          : "My Own New Hivent"
      startYear     : 1900
      startMonth    : 1
      startDay      : 1
      endYear       : 1910
      endMonth      : 1
      endDay        : 1
      displayDate   : "20th century"
      locationName  : "Weimar"
      lng           : 11.0
      lat           : 51.00
      isImp         : yes
      description   : "Please create your own event in here!"
    }

    builder = new HG.HiventBuilder
    hivent = builder._createHivent hiventData
    hiventHandle = new HG.HiventHandle hivent

    # setup new hivent window
    # copy from HiventInfoPopover, let's see how / if that works...
    body = new HG.Div null, ['hivent-body']
    titleDiv = new HG.Div null, ['guiPopoverTitle', 'editable']
    titleDiv.j().html hiventHandle.getHivent().name
    body.appendChild titleDiv
    text = new HG.Div null, ['hivent-content', 'editable']
    text.j().html hiventHandle.getHivent().description
    body.appendChild text

    @_popover = new HG.Popover
      hgInstance:   @_hgInstance
      hiventHandle: hiventHandle
      placement:    "top"
      content:      body
      title:        hiventHandle.getHivent().name
      # container:    container
      # showArrow:    showArrow
      # fullscreen:   !showArrow

    @_popover.onClose @, () ->
      hiventHandle.inActiveAll()

    @_popover.show()

    hiventHandle.onDestruction @, @_popover.destroy



    ### PERFORM ACTION ###


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  _cleanup: () ->

    @_areasOnMap.finishAreaEdit() if @_isForward

    ### CLEANUP OPERATION ###
    # if @_stepData.userInput