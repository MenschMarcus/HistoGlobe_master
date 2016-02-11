window.HG ?= {}

# ==============================================================================
# VIEW class
# set up and handle the change operation window
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
  constructor: (@_hgInstance) ->

    ### MAIN WINDOW ###

    # main window sits on top of hg title, has more height (to account for extra space needed)
    @_mainWindow = new HG.Div 'change-operation-main-window'
    @_mainWindow.dom().style.left = $('#hg-title').position().left + $('#hg-title').width()/2 + 'px'
    @_mainWindow.j().hide()
    @_hgInstance._top_area.appendChild @_mainWindow.dom()


    ### WORKFLOW TABLE ###

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


    ### BUTTONS ###

    # back button (= undo, disabled)
    @_backButton = new HG.Button @_hgInstance, 'coBack', null, [
        {
          'id':       'normal'
          'tooltip':  "Undo / Go Back"
          'iconFA':   'chevron-left'
          'callback': 'onBack'
        }
      ]

    # next button ( = ok = go to next step, disabled)
    # -> changes to OK button / "finish" state in last step
    @_nextButton = new HG.Button @_hgInstance, 'coNext', null, [
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

    # abort button
    @_abortButton = new HG.Button @_hgInstance, 'coAbort', ['button-abort'], [
        {
          'id':       'normal'
          'tooltip':  "Abort Operation"
          'iconFA':   'times'
          'callback': 'onClick'
        }
      ]


  # ============================================================================
  setup: (operation) ->

    ### WORKFLOW TABLE ###

    ## columns ##

    # back column
    @_workflowRow.append new HG.Div null, ['co-workflow-row', 'co-button-col']
    backButtonParent = new HG.Div null, ['co-description-row', 'co-button-col']
    @_descriptionRow.append backButtonParent

    # step columns
    stepCols = 0
    @_stepDescr = []
    for step in operation.steps
      @_workflowRow.append new HG.Div null, ['co-workflow-row', 'co-step-col']
      descr = new HG.Div null, ['co-description-row', 'co-step-col', 'co-description-cell']
      descr.j().html step.title
      @_descriptionRow.append descr
      @_stepDescr.push descr.j()
      stepCols++

    # next column
    abortButtonParent = new HG.Div null, ['co-workflow-row', 'co-button-col']
    @_workflowRow.append abortButtonParent
    nextButtonParent = new HG.Div 'next-button-parent', ['co-description-row', 'co-button-col']
    @_descriptionRow.append nextButtonParent

    ## workflow bar ##
    # spans from first to last step
    # consists of:
    #   a horizontal bar spanning above the steps
    #   three disabled buttons indicating the steps
    #   one moving active marker stating the current step

    cells = @_workflowRow.j().children().toArray()  # contains all workflow cells
    cells.shift()     # removes first element (empty)
    cells.pop()       # removes last element (abort)

    # bounding box of svg canvas: spans all workflow cells
    minX = $(cells[0]).position().left
    minY = $(cells[0]).position().top
    maxX = 0
    maxY = 0

    # position of circles: central positions [x,y] of each workflow cell
    @_circlePos = []
    for cell in cells
      @_circlePos.push {
        'x': $(cell).position().left + $(cell).width()/2 - minX,
        'y': $(cell).position().top + $(cell).height()/2 - minY
      }
      maxX = $(cell).position().left + $(cell).width()
      maxY = $(cell).position().top + $(cell).height()

    # create canvas
    @_workflowCanvas = d3.select @_workflowRow.dom()
      .append 'svg'
      .attr 'id', 'workflow-canvas'
      .style 'left', minX
      .style 'top', minY
      .style 'width', maxX-minX
      .style 'height', maxY-minY

    # draw horizontal line
    @_workflowCanvas
      .append 'line'
      .attr 'id', 'workflow-bar'
      .attr 'x1', @_circlePos[0].x
      .attr 'x2', @_circlePos[@_circlePos.length-1].x
      .attr 'y1', @_circlePos[0].y
      .attr 'y2', @_circlePos[@_circlePos.length-1].y

    # draw a circle for each cell
    rad = HGConfig.button_diameter.val / 2
    circles = @_workflowCanvas.selectAll 'circle'
      .data @_circlePos
      .enter()
      .append 'circle'
      .classed 'workflow-circle', true
      .attr 'cx', (pos) -> pos.x
      .attr 'cy', (pos) -> pos.y
      .attr 'r', rad

    ## identifying current step -> initially start with first step
    @_stepMarker = @_workflowCanvas
      .append 'circle'
      .attr 'id', 'workflow-step-marker'
      .attr 'cx', @_circlePos[0].x
      .attr 'cy', @_circlePos[0].y
      .attr 'r', rad*0.7
    @_stepDescr[0].addClass 'co-current-description'


    ### BUTTONS ###
    backButtonParent.dom().appendChild @_backButton.get()
    nextButtonParent.dom().appendChild @_nextButton.get()
    abortButtonParent.dom().appendChild @_abortButton.get()


    # recenter the window
    # TODO: this does not really work :/
    width =  2        * backButtonParent.j().width()    # 2 button columns
    width += stepCols * HGConfig.operation_step_width.val     # n step columns
    @_mainWindow.j().css 'margin-left', -width/2


  # ============================================================================
  cleanup: () ->
    @_workflowRow.j().empty()
    @_descriptionRow.j().empty()

  # ============================================================================
  show: () ->  @_mainWindow?.j().show()
  hide: () ->  @_mainWindow?.j().hide()

  # ============================================================================
  destroy: () ->
    @_mainWindow?.j().remove()
    delete @_mainWindow?

  # ============================================================================
  # workflow manipulation
  moveStepMarker: (stepIdx) ->
    @_stepMarker
      .transition()
      .attr 'cx', @_circlePos[stepIdx].x

  highlightText: (stepIdx) ->
    d.removeClass 'co-current-description' for d in @_stepDescr
    @_stepDescr[stepIdx].addClass 'co-current-description'



  ##############################################################################
  #                            PRIVATE INTERFACE                                #
  ##############################################################################
