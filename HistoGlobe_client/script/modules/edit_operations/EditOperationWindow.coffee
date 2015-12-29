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

    @_backButton = document.createElement 'div'
    @_backButton.id = 'operation-back-button'
    @_mainWindow.appendChild @_backButton

    @_nextButton = document.createElement 'div'
    @_nextButton.id = 'operation-next-button'
    @_mainWindow.appendChild @_nextButton



    console.log operation.title
