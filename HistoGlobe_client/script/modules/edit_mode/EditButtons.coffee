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
    @_titleBar = new HG.Div 'titlebar', null
    @_titleBar.j().hide()
    @_hgInstance._top_area.appendChild @_titleBar.dom()

    # create edit buttons area
    @_editButtonsArea = new HG.ButtonArea @_hgInstance,
    {
      'id':           'editButtons'
      'positionX':    'right'
      'positionY':    'top'
      'orientation':  'horizontal'
      'direction':    'prepend'
    }

    # create edit button
    @_editButtonsArea.addButton new HG.Button @_hgInstance, 'editMode', null, [
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

    @_editButtonsArea.addSpacer()

    # create new hivent button (hidden)
    @_newHiventButton = new HG.Button @_hgInstance, 'newHivent', null,  [
        {
          'id':       'normal',
          'tooltip':  "Add New Hivent",
          'iconOwn':  iconPath + 'new_hivent.svg',
          'callback': 'onAdd'
        }
      ]
    @_newHiventButton.hide()
    @_editButtonsArea.addButton @_newHiventButton

    @_editButtonsArea.addSpacer()

    # create change operation buttons (hidden)
    @_changeOperationButtons = new HG.ObjectArray

    operations.foreach (operation) =>
      coButton = new HG.Button @_hgInstance, operation.id, ['button-horizontal'], [
          {
            'id':       'normal',
            'tooltip':  operation.title,
            'iconOwn':  iconPath + operation.id + '.svg',
            'callback': 'onStart'
          }
        ]
      coButton.hide()
      @_editButtonsArea.addButton coButton, 'changeOperations-group'

      @_changeOperationButtons.push {
          'id': operation.id,
          'button': coButton
        }


  # ============================================================================
  show: () ->
    @_titleBar.j().show()
    @_newHiventButton.show()
    @_changeOperationButtons.foreach (obj) =>
      obj.button.show()

  hide: () ->
    @_changeOperationButtons.foreach (obj) =>
      obj.button.hide()
    @_newHiventButton.hide()
    @_titleBar.j().hide()

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
