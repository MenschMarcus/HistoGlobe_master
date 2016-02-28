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

    # init config
    defaultConfig =
      editOperationsPath: 'HistoGlobe_client/config/common/editOperations.json'

    @_config = $.extend {}, defaultConfig, config


  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add to HG instance
    @_hgInstance.editMode = @   # N.B. edit mode = edit controller :)

    # loading dependencies + error handling
    if @_hgInstance.map._map?
      @_map = @_hgInstance.map._map
    else
      console.error "Unable to load Edit Mode: There is no map, you idiot! Why would you want to have HistoGlobe without a map ?!?"

    if @_hgInstance.areasOnMap?
      @_areasOnMap = @_hgInstance.areasOnMap
    else
      console.error "Unable to load Edit Mode: AreasOnMap module is not included in the current hg instance (has to be loaded before EditMode)"

    # if @_hgInstance.histoGraph?
    #   @_histoGraph = @_hgInstance.histoGraph
    # else
    #   console.error "Unable to load Edit Mode: HistoGraph module is not included in the current hg instance (has to be loaded before EditMode)"

    # for using the geooperator internally here
    @_geometryOperator = new HG.GeometryOperator
    @_geometryReader = new HG.GeometryReader

    # problem: Edit Mode should listen to each listener only once
    # ugly solution: globally save to which callbacks it has already been added to
    # and prevent from adding more than once
    @_activeCallbacks = {}     # content: { 'nameOfCallback': yes/no}



    ############################################################################
    # TEST PLAYGROUND INIT

    if TEST_BUTTON
      testButton = new HG.Button @_hgInstance, 'test', null, [{'iconFA': 'question','callback': 'onClick'}]
      $(testButton.getDom()).css 'position', 'absolute'
      $(testButton.getDom()).css 'bottom', '0'
      $(testButton.getDom()).css 'right', '0'
      $(testButton.getDom()).css 'z-index', 100
      @_hgInstance._top_area.appendChild testButton.getDom()
      @_testButton = @_hgInstance.buttons.test
      @_testButton.onClick @, () =>

        # TEST PLAYGROUND START HERE

        stepData = {
            id:               'ADD_CHNG'
            title:            "add change <br /> to historical event"
            userInput:        yes
            inData:           {}
          }
        new HG.AddChangeStep @_hgInstance, stepData

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
      @_hgInstance._top_area.appendChild @_editButtonArea.getDom()

      @_editButton = new HG.Button @_hgInstance, 'editMode', null,
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
            currentOperation = @_editOperations.getByPropVal 'id', operationButton.getDom().id
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
    @_newHiventButton = new HG.Button @_hgInstance, 'newHivent', null,
      [
        {
          'id':       'normal',
          'tooltip':  "Add New Hivent",
          'iconOwn':  @_hgInstance._config.graphicsPath + 'buttons/new_hivent.svg',
          'callback': 'onAdd'
        }
      ]
    @_editButtonArea.addButton @_newHiventButton

    # setup operation buttons
    @_editButtonArea.addSpacer()
    @_operationButtons = new HG.ObjectArray
    @_editOperations.foreach (operation) =>
      # add button to UI
      coButton = new HG.Button @_hgInstance, operation.id, ['button-horizontal'],
        [
          {
            'id':       'normal',
            'tooltip':  operation.title,
            'iconOwn':  @_hgInstance._config.graphicsPath + 'buttons/' + operation.id + '.svg',
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