window.HG ?= {}

class HG.EditMode


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @
    # @addCallback

    # init config
    defaultConfig =
      changeOperationsPath: 'HistoGlobe_client/config/common/operations.json'

    @_config = $.extend {}, defaultConfig, config

  # ============================================================================
  hgInit: (@_hgInstance) ->
    @_hgInstance.editMode = @
    @_initEditMode()


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================

  _initEditMode: ->
    # load edit operations
    $.getJSON(@_config.changeOperationsPath, (operations) =>

      # create edit buttons area
      @_editButtonArea = new HG.ButtonArea 'editButtons', 'top-right', 'horizontal'
      @_editButtonArea.hgInit @_hgInstance

      # create edit button
      @_editButton = new HG.Button @,
        {
          'parentArea':   @_editButtonArea,
          'id':           'editButton',
          'states': [
            {
              'id':       'normal',
              'tooltip':  "Enter Edit Mode",
              'iconFA':   'pencil',
              'callback': 'onEnterEditMode'
            },
            {
              'id':       'edit-mode',
              'tooltip':  "Leave Edit Mode",
              'iconFA':   'pencil',
              'callback': 'onLeaveEditMode'
            }
          ]
        }

      # init HG operation controller
      @_changeController = new HG.ChangeController @_editButtonArea, operations
      @_changeController.hgInit @
    )