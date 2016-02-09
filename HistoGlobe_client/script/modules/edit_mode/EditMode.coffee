window.HG ?= {}

class HG.EditMode

  # ==============================================================================
  # EditMode acts as an edit controller has several controlling tasks:
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
    # @addCallback

    # init config
    defaultConfig =
      changeOperationsPath: 'HistoGlobe_client/config/common/hgChangeOperations.json'
      iconPath:             'HistoGlobe_client/config/common/graphics/hgChangeOperations/'

    @_config = $.extend {}, defaultConfig, config

    # init "current" object
    @_curr = {                      # object storing current state of workflow
      op          : null            # object of current operation
      opBtn       : null            # button of current operation
      totalSteps  : null            # total number of steps of current operation
      stepIdx     : null            # number of current step in workflow [starting at 1!]
      step        : null            # object of current step in workflow
    }


  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add to HG instance
    @_hgInstance.editController = @   # N.B. edit mode = edit controller :)

    @_changeOperationButtons = new HG.ObjectArray

    # create transparent title bar (hidden)
    @_titleBar = new HG.Div 'titlebar', null, true
    @_hgInstance._top_area.appendChild @_titleBar.obj()

    # create edit buttons area
    @_editButtonArea = new HG.ButtonArea @_hgInstance,
    {
      'id':           'editButtons'
      'positionX':    'right'
      'positionY':    'top'
      'orientation':  'horizontal'
      'direction':    'prepend'
    }

    # create edit button (show)
    @_editModeButton = new HG.Button @,
      {
        'parentArea':   @_editButtonArea,
        'id':           'editMode',
        'states': [
          {
            'id':       'normal',
            'tooltip':  "Enter Edit Mode",
            'iconFA':   'pencil',
            'callback': 'onEnter'
          },
          {
            'id':       'edit-mode',
            'tooltip':  "Leave Edit Mode",
            'iconFA':   'pencil',
            'callback': 'onLeave'
          }
        ]
      }

    # create new hivent button (hidden)
    @_newHiventButton = new HG.Button @,
      {
        'parentArea':   @_editButtonArea,
        'id':           'newHivent',
        'hide':         yes
        'states': [
          {
            'id':       'normal',
            'tooltip':  "Add New Hivent",
            'iconOwn':  @_config.iconPath + 'new_hivent.svg',
            'callback': 'onAdd'
          }
        ]
      }

    # load all historical geographic change operations
    # and create their buttons (hidden)
    $.getJSON(@_config.changeOperationsPath, (ops) =>

      # operations
      @_hgChangeOperations = new HG.ObjectArray ops # all possible operations

      # setup operation buttons
      @_hgChangeOperations.foreach (operation) =>
        @_changeOperationButtons.push {
          'id': operation.id,
          'button': new HG.Button @_hgInstance,
            {
              'parentArea':   @_editButtonArea,
              'groupName':    'changeOperations'
              'id':           operation.id,
              'hide':         yes,
              'states': [
                {
                  'id':       'normal',
                  'tooltip':  operation.title,
                  'classes':  ['button-horizontal'],
                  'iconOwn':  @_config.iconPath + operation.id + '.svg',
                  'callback': 'onStart'
                }
              ]
            }
        }
    )

    # create title to be filled
    @_title = new HG.Title @_hgInstance


    # -------------------------------------------------------------
    # INTERACTIVITY
    # -------------------------------------------------------------

    # listen to click on edit button => start edit mode
    @_editModeButton.onEnter @, (editButton) ->

      # activate edit button
      editButton.changeState 'edit-mode'
      editButton.activate()

      # show titlebar, new hivent and change operation buttons
      @_titleBar.dom().show()
      @_newHiventButton.show()
      @_changeOperationButtons.foreach (obj) =>
        obj.button.show()

      # update title
      @_title.resize()
      @_title.set 'EDIT MODE'   # TODO internationalization

      # listen to click on edit operation buttons => start operation
      # for operation in @_hgChangeOperations
      @_hgChangeOperations.foreach (operation) =>
        @_hgInstance.buttons[operation.id].onStart @, (btn) =>

          # get operation [json object]
          opId = btn._config.id # to do: more elegant way to get button?
          @_curr.op = @_hgChangeOperations.getByPropVal 'id', opId
          @_curr.opBtn = (@_changeOperationButtons.getById @_curr.op.id).button

          # disable all edit buttons, activate current operation
          @_newHiventButton.disable()
          @_changeOperationButtons.foreach (obj) =>
            obj.button.disable()
          @_curr.opBtn.activate()

          # disable title
          @_title.clear()

          # setup operation window
          @_opWindow.destroy() if @_opWindow? # cleanup before
          @_opWindow = new HG.ChangeOperationWorkflow @_hgInstance, @_curr.op

          # update information about current state in workflow
          @_curr.totalSteps = @_curr.op.steps.length
          @_curr.stepIdx = 1
          @_curr.step = @_curr.op.steps[@_curr.stepIdx-1]

          # disable buttons
          @_opWindow.disableNext()
          @_opWindow.disableBack()


          # listen to click on previous step button
          @_hgInstance.buttons.backButton.onPrevStep @, () =>
            # update information
            unless @_curr.stepIdx is 1
              @_curr.stepIdx--
              @_curr.step = @_curr.op.steps[@_curr.stepIdx-1]
            # change window
            if @_curr.stepIdx is 1
              @_opWindow.disableBack()
            if @_curr.stepIdx is @_curr.totalSteps-1
              @_opWindow.disableFinish()

          # listen to click on next step button
          @_hgInstance.buttons.nextButton.onNextStep @, () =>
              # update information
              unless @_curr.stepIdx is @_curr.totalSteps
                @_curr.stepIdx++
                @_curr.step = @_curr.op.steps[@_curr.stepIdx-1]
              # change window
              @_opWindow.enableBack()
              if @_curr.stepIdx is @_curr.totalSteps
                @_opWindow.enableFinish()

          # listen to click on abort button
          @_hgInstance.buttons.abort.onClick @, () =>
              # remove window
              @_opWindow.destroy()
              # reset buttons
              @_curr.opBtn.deactivate()
              @_changeOperationButtons.foreach (obj) =>
                obj.button.enable()
              @_newHiventButton.enable()
              # reset current operation
              @_curr.op           = null
              @_curr.opBtn        = null
              @_curr.totalSteps   = null
              @_curr.stepIdx      = null
              @_curr.step         = null


    # listen to next click on edit button => leave edit mode
    @_editModeButton.onLeave @, (editButton) ->

      # reset edit button
      editButton.changeState 'normal'
      editButton.deactivate()

      # hide titlebar new hivent and change operation buttons
      @_titleBar.dom().hide()
      @_newHiventButton.hide()
      @_changeOperationButtons.foreach (obj) =>
        obj.button.hide()

      # update title
      @_title.clear()
      @_title.resize()


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================