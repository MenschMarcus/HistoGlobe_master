window.HG ?= {}

# ==============================================================================
# VIEW class
# set up and handle the territory tools for manipulating the geometry
# ==============================================================================

class HG.TerritoryTools

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  constructor: (@_hgInstance) ->

    iconPath = @_hgInstance._config.graphicsPath + 'buttons/'

    ### INIT UI ###

    # moveable wrapper convering everything
    @_wrapper = new HG.Div 'tt-wrapper', null
    @_hgInstance._top_area.appendChild @_wrapper.elem()


    ## 1. line: title
    title = new HG.Div null, ['tt-title']
    title.jq().html "Territory Tools"
    @_wrapper.append title


    ## 2. line: 3 buttons in a button area
    # -> new territory, reuse territory, import territory)
    terrEditButtons = new HG.ButtonArea @_hgInstance, {
      'id':                 'tt-edit-buttons'
      'classes':            ['tt-button-area']
      'parentDiv':          @_wrapper.elem()
      'absolutePosition':   false
    }

    new HG.Button @_hgInstance, {
      'id':                 'newTerritory'
      'parentArea':         terrEditButtons
      'groupName':          'tt-edit-buttons'
      'states': [
        {
          'id':             'normal'
          'tooltip':        "Add new territory"
          'iconOwn':        iconPath + 'geom_add.svg'
          'callback':       'onClick'
        }
      ]
    }
    new HG.Button @_hgInstance, {
      'id':                 'reuseTerritory'
      'parentArea':         terrEditButtons
      'groupName':          'tt-edit-buttons'
      'states': [
        {
          'id':             'normal'
          'tooltip':        "Reuse territory from other times"
          'iconOwn':        iconPath + 'geom_reuse.svg'
          'callback':       'onClick'
        }
      ]
    }
    new HG.Button @_hgInstance, {
      'id':                 'importTerritory'
      'parentArea':         terrEditButtons
      'groupName':          'tt-edit-buttons'
      'states': [
        {
          'id':             'normal'
          'tooltip':        "import territory from file"
          'iconOwn':        iconPath + 'geom_import.svg'
          'callback':       'onClick'
        }
      ]
    }


    ## 3. line: list of existing territories
    @_listWrapper = new HG.Div 'tt-list', null
    @_wrapper.append @_listWrapper


    ## 4. line: snapping options
    # snap to points?, snap to lines? and snap tolerance

    # horizontal wrapper containing all three options
    snapOptionWrapper = new HG.Div 'tt-snap-option-wrapper-out', null
    @_wrapper.append snapOptionWrapper

    # wrapper for each option containing input box + description
    snapToPointsWrapper = new HG.Div null, ['tt-snap-option-wrapper-in']
    snapOptionWrapper.append snapToPointsWrapper
    snapToLinesWrapper = new HG.Div null, ['tt-snap-option-wrapper-in']
    snapOptionWrapper.append snapToLinesWrapper
    snapToleranceWrapper = new HG.Div null, ['tt-snap-option-wrapper-in']
    snapOptionWrapper.append snapToleranceWrapper

    # snap to points
    snapToPointsSwitch = new HG.Switch @_hgInstance, 'snapToPoints', ['tt-snap-option-switch']
    snapToPointsWrapper.append snapToPointsSwitch
    snapToPointsText = new HG.Div null, ['tt-snap-option-text']
    snapToPointsText.jq().html "snap to <br/>border points"
    snapToPointsWrapper.append snapToPointsText

    # snap to lines
    snapToLinesSwitch = new HG.Switch @_hgInstance, 'snapToLines', ['tt-snap-option-switch']
    snapToLinesWrapper.append snapToLinesSwitch
    snapToLinesText = new HG.Div null, ['tt-snap-option-text']
    snapToLinesText.jq().html "snap to <br/>border lines"
    snapToLinesWrapper.append snapToLinesText

    # snap tolerance
    snapToleranceInput = new HG.NumberInput @_hgInstance, 'snapTolerance', ['tt-snap-option-input']
    snapToleranceInput.elem().setAttribute 'value', 5.0
    snapToleranceInput.elem().setAttribute 'maxlength', 3
    snapToleranceInput.elem().setAttribute 'step', 0.1
    snapToleranceInput.elem().setAttribute 'min', 0.0
    snapToleranceInput.elem().setAttribute 'max', 10.0
    snapToleranceWrapper.append snapToleranceInput
    snapToleranceText = new HG.Div null, ['tt-snap-option-text']
    snapToleranceText.jq().html "snap <br/>tolerance [px]"
    snapToleranceWrapper.append snapToleranceText

    ## 5. line: finish buttons
    # -> clip, use rest
    terrFinishButtons = new HG.ButtonArea @_hgInstance, {
      'id':                 'tt-finish-buttons'
      'classes':            ['tt-button-area']
      'parentDiv':          @_wrapper.elem()
      'absolutePosition':   false
    }

    new HG.Button @_hgInstance, {
      'id':                 'clipTerritory'
      'parentArea':         terrFinishButtons
      'groupName':          'tt-finish-buttons'
      'states': [
        {
          'id':             'normal'
          'tooltip':        "Clip Selected Areas"
          'iconOwn':        iconPath + 'polygon_cut.svg'
          'callback':       'onClick'
        }
      ]
    }
    terrFinishButtons.addSpacer 'tt-finish-buttons-group'

    new HG.Button @_hgInstance, {
      'id':                 'useRest'
      'parentArea':         terrFinishButtons
      'groupName':          'tt-finish-buttons'
      'states': [
        {
          'id':             'normal'
          'tooltip':        "Use The Rest as Territory for this Country"
          'iconOwn':        iconPath + 'polygon_rest.svg'
          'callback':       'onClick'
        }
      ]
    }

  # ============================================================================
  destroy: () ->
    @_wrapper?.jq().remove()
    delete @_wrapper?

  # ============================================================================
  addToList: (text) ->
    newT = new HG.Div null, ['tt-list-entry']
    newT.jq().html text
    @_listWrapper.append newT

  # ============================================================================
  clearList: () ->
    @_listWrapper.empty()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================