window.HG ?= {}

class HG.EditMode

  # ==============================================================================
  # EditMode acts as an edit CONTROLLER has several controlling tasks:
  #   register clicks on edit operation buttons -> init operation
  #   manage operation window (init, send data, get data)
  #   handle communication with backend (get data, send data)
  # ==============================================================================


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # init config
    defaultConfig =
      changeOperationsPath: 'HistoGlobe_client/config/common/hgChangeOperations.json'
      iconPath:             'HistoGlobe_client/config/common/graphics/hgChangeOperations/'

    @_config = $.extend {}, defaultConfig, config

    # init variables
    @_hgChangeOperations = null
    @_curr = {                      # object storing current state of workflow
      operation   : null            # object of current operation
      totalSteps  : null            # total number of steps of current operation
      stepIdx     : null            # number of current step in workflow [starting at 1!]
      step        : null            # object of current step in workflow
    }


  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add to HG instance
    @_hgInstance.editController = @   # N.B. edit mode = edit controller :)

    $.getJSON(@_config.changeOperationsPath, (ops) =>

      @_hgChangeOperations = new HG.ObjectArray ops # all possible operations

      @_editButtons = new HG.EditButtons @_hgInstance, @_hgChangeOperations, @_config.iconPath
      @_editModeButton = @_editButtons.getEditButton()
      @_title = new HG.Title @_hgInstance


      # listen to click on edit button => start edit mode
      @_editModeButton.onEnter @, () ->

        @_editButtons.activateEditButton()
        @_editButtons.show()
        @_title.resize()
        @_title.set 'EDIT MODE'   # TODO internationalization

        # listen to click on edit operation buttons => start operation
        @_hgChangeOperations.foreach (operation) =>
          @_hgInstance.buttons[operation.id].onStart @, (btn) =>

            # update information about current state in workflow
            opId = btn._config.id # to do: more elegant way to get id?
            @_curr.operation = @_hgChangeOperations.getByPropVal 'id', opId
            @_curr.totalSteps = @_curr.operation.steps.length
            @_curr.stepIdx = 1
            @_curr.step = @_curr.operation.steps[@_curr.stepIdx-1]

            # setup UI
            @_editButtons.disable()
            @_editButtons.activate @_curr.operation.id
            @_title.clear()
            @_coWindow?.destroy()
            @_coWindow = new HG.ChangeOperationWindow @_hgInstance, @_curr.operation

            # listen to click on previous step button
            # TODO: implement actual "undo"
            @_hgInstance.buttons.coBack.onBack @, () =>
              # update information
              unless @_curr.stepIdx is 1
                @_curr.stepIdx--
                @_curr.step = @_curr.operation.steps[@_curr.stepIdx-1]
              # change window
              @_coWindow.disableBack()          if @_curr.stepIdx is 1
              @_coWindow.disableFinishButton()  if @_curr.stepIdx is @_curr.totalSteps-1


            # listen to click on next step button
            @_hgInstance.buttons.coNext.onNext @, () =>
                # update information
                unless @_curr.stepIdx is @_curr.totalSteps
                  @_curr.stepIdx++
                  @_curr.step = @_curr.operation.steps[@_curr.stepIdx-1]
                # change window
                @_coWindow.enableBack()
                @_coWindow.enableFinishButton() if @_curr.stepIdx is @_curr.totalSteps

            # listen to click on abort button
            @_hgInstance.buttons.coAbort.onClick @, () =>
                # reset UI
                @_coWindow.destroy()
                @_editButtons.deactivate @_curr.operation.id
                @_editButtons.enable @_curr.operation.id
                # reset current operation
                @_curr.operation    = null
                @_curr.totalSteps   = null
                @_curr.stepIdx      = null
                @_curr.step         = null


      # listen to next click on edit button => leave edit mode and cleanup
      @_editModeButton.onLeave @, () ->
        @_coWindow?.destroy()
        @_editButtons.deactivateEditButton()
        @_editButtons.hide()
        @_title.clear()

    )

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================