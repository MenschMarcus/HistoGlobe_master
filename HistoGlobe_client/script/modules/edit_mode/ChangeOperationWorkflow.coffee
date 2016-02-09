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

class HG.ChangeOperationWorkflow

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
  constructor: (@_hgInstance, @_operation) ->

    # add to HG instance
    @_hgInstance.changeOperationWorkflow = @

    # init callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # init variables
    @_nextDisabled = false
    @_backDisabled = false


    ### divs ###

    # main window sits on top of hg title, has more height (to account for extra space needed)
    @_mainWindow = new HG.Div 'change-operation-main-window'
    @_mainWindow.obj().style.left = $('#hg-title').position().left + $('#hg-title').width()/2 + 'px'
    @_hgInstance._top_area.appendChild @_mainWindow.obj()

    # table layout    |stepBack| step1 | step. | stepn |stepNext|
    # -------------------------------------------------------------------
    # workflowRow     |        |  (O)--|--( )--|--( )  |    X   |   -> hg title
    # descriptionRow  |   (<)  | text1 | text. | textn |   (>)  |   + semi-transparent bg

    # create workflow and description divs that dynamically adjust to their content
    @_workflowRow = new HG.Div 'change-operation-workflow-wrapper'
    @_mainWindow.append @_workflowRow

    @_descriptionRow = new HG.Div 'change-operation-description-wrapper'
    @_mainWindow.append @_descriptionRow

    # setup table
    @_setColumns @_operation


    ### buttons ###

    # back button (= undo)
    @_backButton = new HG.Button @_hgInstance,
      {
        'parentDiv':  @_backButtonParent.obj()
        'id':         'backButton'
        'states': [
          {
            'id':       'normal'
            'tooltip':  "Undo / Go Back"
            'iconFA':   'chevron-left'
            'callback': 'onPrevStep'
          }
        ]
      }

    # next button ( = ok, go to next step)
    # -> changes to OK button / "finish" state in last step
    @_nextButton = new HG.Button @_hgInstance,
      {
        'parentDiv':    @_nextButtonParent.obj()
        'id':           'nextButton'
        'states': [
          {
            'id':       'normal'
            'tooltip':  "Done / Next Step"
            'iconFA':   'chevron-right'
            'callback': 'onNextStep'
          },
          {
            'id':       'finish'
            'tooltip':  "Done / Next Step"
            'iconFA':   'check'
            'callback': 'onFinishOperation'
          },
        ]
      }

    ## 3) abort button
    @_abortButton = new HG.Button @_hgInstance,
      {
        'parentDiv':    @_abortButtonParent.obj()
        'id':           'abort'
        'states': [
          {
            'id':       'normal'
            'classes':  ['button-abort']
            'tooltip':  "Abort Operation"
            'iconFA':   'times'
            'callback': 'onClick'
          }
        ]
      }

  # ============================================================================
  destroy: () ->
    @_mainWindow.dom().remove()

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
    @_nextButton.changeState 'finish'

  disableFinish: () ->
    @_nextButton.changeState 'normal'


  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################

  # ============================================================================
  _setColumns: (op) ->
    # back column
    @_workflowRow.append new HG.Div null, ['co-workflow-row', 'co-button-col']
    @_backButtonParent = new HG.Div null, ['co-description-row', 'co-button-col']
    @_descriptionRow.append @_backButtonParent

    # step columns
    cols = 0
    for step in op.steps
      @_workflowRow.append new HG.Div null, ['co-workflow-row', 'co-step-col']
      descr = new HG.Div null, ['co-description-row', 'co-step-col', 'co-description-cell']
      descr.dom().html step.title
      @_descriptionRow.append descr
      cols++

    # next column
    @_abortButtonParent = new HG.Div null, ['co-workflow-row', 'co-button-col']
    @_workflowRow.append @_abortButtonParent
    @_nextButtonParent = new HG.Div null, ['co-description-row', 'co-button-col']
    @_descriptionRow.append @_nextButtonParent

    @_recenterWindow cols

  # ============================================================================
  _recenterWindow: (numCols) ->
    width =  2       * @_backButtonParent.dom().width()     # 2 button columns
    width += numCols * HGConfig.operation_step_width.val    # n step columns
    @_mainWindow.dom().css 'margin-left', -width/2    # recenters div
