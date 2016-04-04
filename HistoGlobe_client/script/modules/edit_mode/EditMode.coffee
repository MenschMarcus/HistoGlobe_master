window.HG ?= {}

# DEBUG: take out if not needed anymore
TEST_BUTTON = yes

# ==============================================================================
# EditMode registers clicks on edit operation buttons -> init operation
#   manage operation window (init, send data, get data)
#   handle communication with backend (get data, send data)
# ==============================================================================


class HG.EditMode

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onEnableMultiSelection'
    @addCallback 'onDisableMultiSelection'
    @addCallback 'onEnableAreaEditMode'
    @addCallback 'onDisableAreaEditMode'

    @addCallback 'onCreateArea'
    @addCallback 'onUpdateAreaGeometry'
    @addCallback 'onUpdateAreaRepresentativePoint'
    @addCallback 'onAddAreaName'
    @addCallback 'onUpdateAreaName'
    @addCallback 'onRemoveAreaName'
    @addCallback 'onRemoveArea'

    @addCallback 'onActivateArea'
    @addCallback 'onDeactivateArea'
    @addCallback 'onSelectArea'
    @addCallback 'onDeselectArea'
    @addCallback 'onStartEditArea'
    @addCallback 'onEndEditArea'

    @addCallback 'onCreateHivent'


    # init config
    defaultConfig =
      editOperationsPath: 'common/editOperations.json'

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add to HG instance
    @_hgInstance.editMode = @   # N.B. edit mode = edit controller :)

    # append pathes
    @_config.editOperationsPath = @_hgInstance.config.configPath + @_config.editOperationsPath


    ############################################################################
    if TEST_BUTTON
      testButton = new HG.Button @_hgInstance, 'test', null, [{'iconFA': 'question','callback': 'onClick'}]
      $(testButton.getDOMElement()).css 'position', 'absolute'
      $(testButton.getDOMElement()).css 'bottom', '0'
      $(testButton.getDOMElement()).css 'right', '0'
      $(testButton.getDOMElement()).css 'z-index', 100
      @_hgInstance.getTopArea().appendChild testButton.getDOMElement()
      @_testButton = @_hgInstance.buttons.test
      @_testButton.onClick @, () =>

        # TEST PLAYGROUND START HERE
        examplePath = @_hgInstance.config.configPath + 'common/example.json'

        $.getJSON(examplePath, (request) =>

          # save to server
          $.ajax
            url:  'save_operation/'
            type: 'POST'
            data: JSON.stringify request

            # success callback: add id to hivent and save it in hivent controller
            success: (response) =>
              data = $.parseJSON response
              console.log data
              # save hivent
              @notifyAll 'onCreateHivent', data.hivent

              # update areas
              for areaData in data.new_areas
                area = @_hgInstance.areaController.getArea areaData.old_id
                area.setId areaData.new_id


            # error callback: print error
            error: (xhr, errmsg, err) =>
              console.log xhr
              console.log errmsg, err
              console.log xhr.responseText
        )

        # TEST PLAYGROUND END HERE
    ############################################################################


    # init everything
    $.getJSON(@_config.editOperationsPath, (operationConfig) =>

      # load operations
      @_editOperations = new HG.ObjectArray operationConfig # all possible operations

      # setup edit button area and add editButton to it
      # is always there, never has to be destructed
      @_editButtonArea = new HG.ButtonArea @_hgInstance,
      {
        'id':           'editButtons'
        'posX':         'right'
        'posY':         'top'
        'orientation':  'horizontal'
        'direction':    'prepend'
      }
      @_hgInstance.getTopArea().appendChild @_editButtonArea.getDOMElement()

      @_editButton = new HG.Button @_hgInstance,
        'editMode', ['tooltip-left'],
        [
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
      @_editButtonArea.addButton @_editButton


      ### EDIT HIERACHY: EDIT MODE -> OPERATION -> STEP -> ACTION ###

      ## (1) EDIT MODE ##
      # listen to click on edit button => start edit mode
      @_editButton.onEnter @, () ->

        @_setupEditMode()

        ## (2) OPERATION ##
        # listen to click on edit operation buttons => start operation
        @_operationButtons.foreach (operationButton) =>
          operationButton.button.onClick @, (operationButton) =>

            # get current operation
            currentOperation = @_editOperations.getByPropVal 'id', operationButton.getDOMElement().id
            @_operationId = currentOperation.id
            # TODO (opId_move_to_operation)
            # clean design: the EditMode should not need to know which
            # operation is active. Instead, the EditOperation does and this one
            # should tell the button to activate

            # setup new operation and move all the controlling logic in there
            @_setupOperation()
            operation = new HG.EditOperation @_hgInstance, currentOperation

            # wait for operation to finish
            operation.onFinish @, () =>
              @_cleanupOperation()


      # listen to next click on edit button => leave edit mode and cleanup
      @_editButton.onLeave @, () ->
        @_cleanupEditMode()
    )


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _setupEditMode: () ->
    # activate edit button
    @_editButton.changeState 'edit-mode'
    @_editButton.activate()

    # setup new hivent button
    @_editButtonArea.addSpacer()
    @_newHiventButton = new HG.Button @_hgInstance,
      'newHivent', ['tooltip-bottom'],
      [
        {
          'id':       'normal',
          'tooltip':  "Add New Hivent",
          'iconOwn':  @_hgInstance.config.graphicsPath + 'buttons/new_hivent.svg',
          'callback': 'onClick'
        }
      ]
    @_editButtonArea.addButton @_newHiventButton

    # setup operation buttons
    @_editButtonArea.addSpacer()
    @_operationButtons = new HG.ObjectArray
    @_editOperations.foreach (operation) =>
      # add button to UI
      coButton = new HG.Button @_hgInstance,
        operation.id, ['button-horizontal', 'tooltip-bottom'],
        [
          {
            'id':       'normal',
            'tooltip':  operation.title,
            'iconOwn':  @_hgInstance.config.graphicsPath + 'buttons/' + operation.id + '.svg',
            'callback': 'onClick'
          }
        ]
      @_editButtonArea.addButton coButton, 'changeOperations-group'
      # add button in object array to keep track of it
      @_operationButtons.push {
          'id': operation.id,
          'button': coButton
        }

    # setup title
    @_title = new HG.Title @_hgInstance, "EDIT MODE" # TODO: internationalization

  # ----------------------------------------------------------------------------
  _cleanupEditMode: () ->
    # remove title
    @_title.destroy()

    # remove operation buttons
    @_operationButtons.foreach (b) =>
      b.button.destroy()

    # remove new hivent button
    @_newHiventButton.destroy()

    # deactivate edit button
    @_editButton.deactivate()
    @_editButton.changeState 'normal'


  # ============================================================================
  _setupOperation: () ->
    # disable all buttons
    @_editButton.disable()
    @_newHiventButton.disable()
    @_operationButtons.foreach (obj) =>
      obj.button.disable()

    # highlight button of current operation
    # TODO (opId_move_to_operation)
    (@_operationButtons.getById @_operationId).button.activate()

    # setup workflow window (in the space of the title)
    @_title.clear()

  # ----------------------------------------------------------------------------
  _cleanupOperation: () ->
    # restore title
    @_title.set "EDIT MODE"   # TODO: internationalization

    # deactivate button of current operation
    # TODO (opId_move_to_operation)
    (@_operationButtons.getById @_operationId).button.deactivate()

    # enable all buttons
    @_newHiventButton.enable()
    @_operationButtons.foreach (obj) =>
      obj.button.enable()
    @_newHiventButton.enable()
    @_editButton.enable()