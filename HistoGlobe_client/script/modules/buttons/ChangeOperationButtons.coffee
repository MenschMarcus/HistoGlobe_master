window.HG ?= {}

class HG.ChangeOperationButtons

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_editButtonArea, @_operations, @_iconPath) ->

  # ============================================================================
  hgInit: (@_hgInstance) ->

    @_hgInstance.edit_operation_buttons = @

    # init buttons for each operation
    @_buttons = new HG.ObjectArray

    @_operations.foreach (operation) =>
      @_buttons.push {
        'id':   operation.id,
        'btn':  new HG.Button @_hgInstance,
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
      }


  # ============================================================================
  enable: () ->
    @_buttons.foreach (obj) =>
      $(obj.btn._button).removeClass('button-disabled')

  # ============================================================================
  disable: () ->
    @_buttons.foreach (obj) =>
      $(obj.btn._button).addClass('button-disabled')

  # ============================================================================
  activate: (opid) ->
    obj = @_buttons.getByPropVal 'id', opid
    obj.btn.activate()

  # ============================================================================
  deactivate: (opid) ->
    obj = @_buttons.getByPropVal 'id', opid
    obj.btn.deactivate()

  # ============================================================================
  destroy: () ->
    @_editButtonArea.removeButtonGroup 'editOperations'

