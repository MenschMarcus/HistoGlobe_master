window.HG ?= {}

# ==============================================================================
# VIEW class
# set up and handle edit buttons on the top right corner of the screen
# ==============================================================================

class HG.EditButtons

  # ============================================================================
  constructor: (@_hgInstance, operations) ->

    # add to HG instance
    @_hgInstance.editButtons = @

    iconPath = @_hgInstance._config.graphicsPath + 'buttons/'

    # create transparent title bar (hidden)
    @_titleBar = new HG.Div 'titlebar', null, true
    @_hgInstance._top_area.appendChild @_titleBar.elem()

    # create edit buttons area
    @_editButtonsArea = new HG.ButtonArea @_hgInstance,
    {
      'id':           'editButtons'
      'positionX':    'right'
      'positionY':    'top'
      'orientation':  'horizontal'
      'direction':    'prepend'
    }

    # create edit button (show)
    @_editModeButton = new HG.Button @,
      {
        'parentArea':   @_editButtonsArea,
        'id':           'editMode',
        'states': [
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
      }

    @_editButtonsArea.addSpacer()

    # create new hivent button (hidden)
    @_newHiventButton = new HG.Button @,
      {
        'parentArea':   @_editButtonsArea,
        'id':           'newHivent',
        'hide':         yes
        'states': [
          {
            'id':       'normal',
            'tooltip':  "Add New Hivent",
            'iconOwn':  iconPath + 'new_hivent.svg',
            'callback': 'onAdd'
          }
        ]
      }

    @_editButtonsArea.addSpacer()

    # create change operation buttons (hidden)
    @_changeOperationButtons = new HG.ObjectArray

    operations.foreach (operation) =>
      @_changeOperationButtons.push {
        'id': operation.id,
        'button': new HG.Button @_hgInstance,
          {
            'parentArea':   @_editButtonsArea,
            'groupName':    'changeOperations'
            'id':           operation.id,
            'hide':         yes,
            'states': [
              {
                'id':       'normal',
                'tooltip':  operation.title,
                'classes':  ['button-horizontal'],
                'iconOwn':  iconPath + operation.id + '.svg',
                'callback': 'onStart'
              }
            ]
          }
      }


  getEditButton: () -> @_editModeButton

  # ============================================================================
  activateEditButton: () ->
    @_editModeButton.changeState 'edit-mode'
    @_editModeButton.activate()

  deactivateEditButton: () ->
    @_editModeButton.changeState 'normal'
    @_editModeButton.deactivate()

  # ============================================================================
  show: () ->
    $(@_titleBar.elem()).show()
    @_newHiventButton.show()
    @_changeOperationButtons.foreach (obj) =>
      obj.button.show()

  hide: () ->
    @_changeOperationButtons.foreach (obj) =>
      obj.button.hide()
    @_newHiventButton.hide()
    $(@_titleBar.elem()).hide()

  # ============================================================================
  disable: () ->
    @_newHiventButton.disable()
    @_changeOperationButtons.foreach (obj) =>
      obj.button.disable()

  # ============================================================================
  enable: () ->
    @_newHiventButton.enable()
    @_changeOperationButtons.foreach (obj) =>
      obj.button.enable()

  # ============================================================================
  activate: (stepId) ->
    (@_changeOperationButtons.getById stepId).button.activate()

  deactivate: (stepId) ->
    (@_changeOperationButtons.getById stepId).button.deactivate()
