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
  constructor: (parentDiv, operation) ->
    @_op = operation

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


    # initially create back and next buttons
    @_backButton = @_makeButton 'back-button', "Undo / Go Back", 'chevron-left'
    @_nextButton = @_makeButton 'next-button', "Done / Next Step", 'chevron-right'
    @_mainWindow.appendChild @_backButton
    @_mainWindow.appendChild @_nextButton

    # buttons will be set active / inactive throughout the workflow
    # next button will be replaced by OK button in last step

    # setup window
    @_setTitle @_op.title
    @_setColumns @_op

  # ============================================================================
  destroy: () ->
    $(@_mainWindow).remove()


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

  # ============================================================================
  _makeButton: (id, title, faIcon) ->
    # button itself
    button = document.createElement 'div'
    button.id = id
    button.className = 'button'
    $(button).tooltip {
      title: title,
      placement: 'right',
      container: 'body'
    }
    # font awesome icon
    icon = document.createElement 'i'
    icon.className = 'fa fa-' + faIcon
    button.appendChild icon
    button
