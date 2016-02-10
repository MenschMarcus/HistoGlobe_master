window.HG ?= {}

# ==============================================================================
# VIEW class
# set up and handle the edit operation window
#   edit operations: ADD, UNI, SEP, CHB, CHN, DEL
# steps:
#   1) select old country/-ies
#   2) set geometry of new country/-ies
#   3) set name of new country/-ies
#   4) add change to hivent
# ==============================================================================

class HG.ChangeOperationWindow

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # operation = json object containing relevant information for window
  #   title:    window title
  #   numOld:   number of old countries selected (null, '1', '2', '1+', '2+')
  #   numNew:   number of new countries created (null, '1', '2', '1+', '2+')
  #   newGeo:   set geometry of new country/-ies? (bool)
  #   newName:  set name of new country/-ies? (bool)
  # ============================================================================
  constructor: (@_hgInstance, @_operation) ->

    # init variables
    @_nextDisabled = no
    @_backDisabled = no

    ### divs ###

    # main window sits on top of hg title, has more height (to account for extra space needed)
    @_mainWindow = new HG.Div 'change-operation-main-window'
    @_mainWindow.obj().style.left = $('#hg-title').position().left + $('#hg-title').width()/2 + 'px'
    @_hgInstance._top_area.appendChild @_mainWindow.obj()

    # table layout    |stepBack| step1 | step. | stepn |stepNext|
    # -------------------------------------------------------------------
    # workflowRow     |        |  (O)--|--( )--|--( )  |    X   |   -> hg title
    # descriptionRow  |   (<)  | text1 | text. | textn |   (>)  |   + semi-transparent bg

    ## rows ##
    # create workflow and description divs that dynamically adjust to their content
    @_workflowRow = new HG.Div 'change-operation-workflow-wrapper'
    @_mainWindow.append @_workflowRow

    @_descriptionRow = new HG.Div 'change-operation-description-wrapper'
    @_mainWindow.append @_descriptionRow

    ## columns ##
    # back column
    @_workflowRow.append new HG.Div null, ['co-workflow-row', 'co-button-col']
    @_backButtonParent = new HG.Div null, ['co-description-row', 'co-button-col']
    @_descriptionRow.append @_backButtonParent

    # step columns
    stepCols = 0
    for step in @_operation.steps
      @_workflowRow.append new HG.Div null, ['co-workflow-row', 'co-step-col']
      descr = new HG.Div null, ['co-description-row', 'co-step-col', 'co-description-cell']
      descr.dom().html step.title
      @_descriptionRow.append descr
      stepCols++

    # next column
    @_abortButtonParent = new HG.Div null, ['co-workflow-row', 'co-button-col']
    @_workflowRow.append @_abortButtonParent
    @_nextButtonParent = new HG.Div null, ['co-description-row', 'co-button-col']
    @_descriptionRow.append @_nextButtonParent


    ### buttons ###

    # back button (= undo, disabled)
    @_backButton = new HG.Button @_hgInstance,
      {
        'parentDiv':  @_backButtonParent.obj()
        'id':         'coBack'
        'states': [
          {
            'id':       'normal'
            'tooltip':  "Undo / Go Back"
            'iconFA':   'chevron-left'
            'callback': 'onBack'
          }
        ]
      }

    # next button ( = ok = go to next step, disabled)
    # -> changes to OK button / "finish" state in last step
    @_nextButton = new HG.Button @_hgInstance,
      {
        'parentDiv':    @_nextButtonParent.obj()
        'id':           'coNext'
        'states': [
          {
            'id':       'normal'
            'tooltip':  "Done / Next Step"
            'iconFA':   'chevron-right'
            'callback': 'onNext'
          },
          {
            'id':       'finish'
            'tooltip':  "Done / Next Step"
            'iconFA':   'check'
            'callback': 'onFinish'
          },
        ]
      }

    # abort button
    @_abortButton = new HG.Button @_hgInstance,
      {
        'parentDiv':    @_abortButtonParent.obj()
        'id':           'coAbort'
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

    # recenter the window
    width =  2        * @_backButtonParent.dom().width()     # 2 button columns
    width += stepCols * HGConfig.operation_step_width.val    # n step columns
    @_mainWindow.dom().css 'margin-left', -width/2    # recenters div


  # ============================================================================
  destroy: () ->
    @_mainWindow?.dom().remove()
    delete @_mainWindow?

  # ============================================================================
  # button manipulation
  disableNext: () ->
    unless @_nextDisabled
      @_nextButton.disable()
      @_nextDisabled = yes

  enableNext: () ->
    if @_nextDisabled
      @_nextButton.enable()
      @_nextDisabled = no

  disableBack: () ->
    unless @_backDisabled
      @_backButton.disable()
      @_backDisabled = yes

  enableBack: () ->
    if @_backDisabled
      @_backButton.enable()
      @_backDisabled = no

  enableFinish: () ->
    @_nextButton.changeState 'finish'

  disableFinish: () ->
    @_nextButton.changeState 'normal'


  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################
