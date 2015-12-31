window.HG ?= {}

# ==============================================================================
# Superclass for an edit operation window
#   edit operations: ADD, UNI, SEP, CHB, CHN, DEL
# three steps:
#   1) select old country/-ies
#   2) set geometry of new country/-ies
#   3) set name of new country/-ies
# purpose of the class
#   set up the window
#   manage the work flow including data in / out
# ==============================================================================

class HG.EditOperationWindow


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # Constructor
  #   parentDiv = main HistoGlobe div
  #   operation = json object containing relevant information for window
  #     title = window title
  #     numOld = number of old countries selected (null, '1', '2', '1+', '2+')
  #     numNew = number of new countries created (null, '1', '2', '1+', '2+')
  #     newGeo = set geometry of new country/-ies? (bool)
  #     newName = set name of new country/-ies? (bool)
  # ============================================================================
  constructor: (hgInstance, parentDiv, operation) ->

    # init variables
    @_op = operation
    @_nextDisabled = false
    @_backDisabled = false

    # add object to HG instance
    @_hgInstance = hgInstance
    @_hgInstance.edit_operation_window = @

    # init callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # create basic operation work flow divs
    @_mainWindow = document.createElement 'div'
    @_mainWindow.id = 'operation-main-window'
    parentDiv.appendChild @_mainWindow

    @_title = document.createElement 'div'
    @_title.id = 'operation-title'
    @_mainWindow.appendChild @_title

    @_workflow = document.createElement 'div'
    @_workflow.id = 'operation-workflow'
    @_mainWindow.appendChild @_workflow

    @_content = document.createElement 'div'
    @_content.id = 'operation-content'
    @_mainWindow.appendChild @_content

    # create buttons

    ## 1) back button (only one state)
    @_backButton = new HG.Button(
      @_hgInstance,
      @_mainWindow
      'backButton',
      [
        {
          'id':       'normal',
          'tooltip':  "Undo / Go Back",
          'iconFA':   'chevron-left',
          'callback': 'onPrevStep'
        }
      ]
    )

    ## 2) next button (changes to "finish" state in last step)
    @_nextButton = new HG.Button(
      @_hgInstance,
      @_mainWindow
      'nextButton',
      [
        {
          'id':       'normal',
          'tooltip':  "Done / Next Step",
          'iconFA':   'chevron-right',
          'callback': 'onNextStep'
        },
        {
          'id':       'finish',
          'tooltip':  "Done / Next Step",
          'iconFA':   'check',
          'callback': 'onFinishOperation'
        },
      ]
    )

    # setup window
    @_setTitle @_op.title
    @_setColumns @_op

  # ============================================================================
  destroy: () ->
    $(@_mainWindow).remove()

  # ============================================================================
  disableNext: () ->
    unless @_nextDisabled
      @_nextButton.disable()
      @_nextDisabled = true

  enableNext: () ->
    if @_nextDisabled
      @_nextButton.enable()
      @_nextDisabled = false

  disableBack: () ->
    unless @_backDisabled
      @_backButton.disable()
      @_backDisabled = true

  enableBack: () ->
    if @_backDisabled
      @_backButton.enable()
      @_backDisabled = false


  # ============================================================================
  enableFinish: () ->
    @_nextButton.changeState('finish')

  disableFinish: () ->
    @_nextButton.changeState('normal')


  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################


  # ============================================================================
  _setTitle: (title) ->
    $(@_title).text title

  # ============================================================================
  _setColumns: (op) ->
    for step in op.steps

      # title (in workflow bar)
      titleCol = document.createElement 'div'
      titleCol.id = step.id + '-title'
      titleCol.className = 'operation-step'
      titleCol.innerHTML = step.title
      @_workflow.appendChild titleCol

      # main content
      contentCol = document.createElement 'div'
      contentCol.id = step.id + '-content'
      contentCol.className = 'operation-step'
      @_content.appendChild contentCol

    @_recenterWindow op.steps.length

  # ============================================================================
  _recenterWindow: (numCols) ->
    width = numCols * HGConfig.operation_step_width.val + HGConfig.operation_window_border.val
    $(@_mainWindow).css 'margin-left', -width/2    # recenters div
