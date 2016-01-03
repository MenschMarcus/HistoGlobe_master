window.HG ?= {}

class HG.OperationButtons

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_editButtonArea, @_operations, @_iconPath) ->

  # ============================================================================
  hgInit: (@_hgInstance) ->
    # init buttons for each operation
    @_operations.foreach (operation) =>
      new HG.Button @_hgInstance,
        {
          'parentArea':   @_editButtonArea,
          'groupName':    'editOperations'
          'id':           operation.id,
          'states': [
            {
              'id':       'normal',
              'tooltip':  operation.title,
              'classes':  ['button-horizontal'],
              'iconOwn':  @_iconPath + operation.id + '.svg',
              'callback': 'onStart'
            }
          ]
        }

  # ============================================================================
  destroy: () ->
    @_editButtonArea.removeButtonGroup 'editOperations'

