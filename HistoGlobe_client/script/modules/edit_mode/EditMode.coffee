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
    @_currCO = {}                   # object of current change operation
    @_currStep = {}                 # object of current step in workflow


  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add to HG instance
    @_hgInstance.editController = @   # N.B. edit mode = edit controller :)

    $.getJSON(@_config.changeOperationsPath, (ops) =>

      @_hgChangeOperations = new HG.ObjectArray ops # all possible operations

      @_editButtons = new HG.EditButtons @_hgInstance, @_hgChangeOperations, @_config.iconPath
      @_editModeButton = @_editButtons.getEditButton()
      @_title = new HG.Title @_hgInstance
      @_histoGraph = @_hgInstance.histoGraph
      @_areasOnMap = @_hgInstance.areasOnMap

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
            @_currCO = @_hgChangeOperations.getByPropVal 'id', opId
            @_currCO.totalSteps = @_currCO.steps.length
            @_currCO.stepIdx = 0
            @_currCO.finished = no

            # setup UI
            @_editButtons.disable()
            @_editButtons.activate @_currCO.id
            @_title.clear()
            @_coWindow?.destroy()
            @_coWindow = new HG.ChangeOperationWindow @_hgInstance, @_currCO
            @_histoGraph.show()

            while not @_currCO.finished
              @_currStep = @_currCO.steps[@_currCO.stepIdx]
              @_currStep.num = @_getRequiredNum @_currStep.num

              console.log @_currStep

              # determine required action for current step
              switch @_currStep.id
                when 'SEL_OLD' then (
                  @_areasOnMap.enableMultipleSelection @_currStep.num.max
                  @_selectedAreas = new HG.ObjectArray
                  @_selectedAreas.push @_areasOnMap.getActiveArea() if @_areasOnMap.getActiveArea()?

                  @_areasOnMap.onSelectArea @, (area) =>
                    @_selectedAreas.push area
                    @_histoGraph.addToSelection area

                    # check if step is completed
                    console.log @_selectedAreas.length(), @_currStep.num.min
                    if @_selectedAreas.length() >= @_currStep.num.min
                      @_coWindow.enableNext()

                  @_areasOnMap.onDeselectArea @, (area) =>
                    console.log @_selectedAreas
                    @_selectedAreas.remove '_id', area._id
                    @_histoGraph.removeFromSelection area

                    # check if step is completed
                    console.log @_selectedAreas.length(), @_currStep.num.min
                    if @_selectedAreas.length() < @_currStep.num.min
                      @_coWindow.disableNext()
                )

                # when 'SET_GEOM' then

                # when 'SET_NAME' then

                # when 'SET_CHNG' then


              @_currCO.stepIdx++

              if @_currCO.stepIdx is @_currCO.totalSteps
                @_currCO.finished = yes

              # DEBUG
              break



            # listen to click on previous step button
            # TODO: implement actual "undo"
            @_hgInstance.buttons.coBack.onBack @, () =>
              # update information
              unless @_currCO.stepIdx is 1
                @_currCO.stepIdx--
                @_currStep = @_currCO.steps[@_currCO.stepIdx-1]
              # change window
              @_coWindow.disableBack()          if @_currCO.stepIdx is 1
              @_coWindow.disableFinishButton()  if @_currCO.stepIdx is @_curr.totalSteps-1

            # listen to click on next step button
            @_hgInstance.buttons.coNext.onNext @, () =>
                # update information
                unless @_currCO.stepIdx is @_curr.totalSteps
                  @_currCO.stepIdx++
                  @_currStep = @_currCO.steps[@_currCO.stepIdx-1]
                # change window
                @_coWindow.enableBack()
                @_coWindow.enableFinishButton() if @_currCO.stepIdx is @_curr.totalSteps

            # listen to click on abort button
            @_hgInstance.buttons.coAbort.onClick @, () =>
                # reset UI
                @_coWindow.destroy()
                @_editButtons.deactivate @_currCO.id
                @_editButtons.enable @_currCO.id
                # reset current operation
                @_currCO    = null
                @_currStep  = null


      # listen to next click on edit button => leave edit mode and cleanup
      @_editModeButton.onLeave @, () ->
        @_coWindow?.destroy()
        @_editButtons.deactivate @_currCO.id
        @_editButtons.enable @_currCO.id
        @_editButtons.deactivateEditButton()
        @_editButtons.hide()
        @_title.clear()

    )

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # possible inputs:  1   1+  2   2+
  MAX_NUM = 25
  _getRequiredNum: (exp) ->
    lastChar = exp.substr(exp.length-1)
    max = if lastChar is '+' then MAX_NUM else lastChar
    min = (exp.substring 0,1)
    {'min': parseInt(min), 'max': parseInt(max)}