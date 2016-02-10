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

    ### init UI ###

    # moveable wrapper convering everything
    wrapper = new HG.Div 'tt-wrapper', null
    @_hgInstance._top_area.appendChild wrapper.elem()


    ## 1. line: title
    title = new HG.Div null, ['tt-title', 'h1']
    title.jq().html "Territory Tools"
    wrapper.append title


    ## 2. line: 3 buttons in a button area
    # -> new territory, reuse territory, import territory)
    terrEditButtons = new HG.ButtonArea @_hgInstance, {
      'id':                 'tt-edit-buttons'
      'classes':            ['tt-button-area']
      'parentDiv':          wrapper.elem()
      'absolutePosition':   false
    }

    newTerrButton = new HG.Button @_hgInstance, {
      'id':                 'newTerritory'
      'parentArea':         terrEditButtons
      'groupName':          'tt-edit-buttons'
      'states': [
        {
          'id':             'normal'
          'tooltip':        "Add new territory"
          'iconFA':         'plus'
          'callback':       'onClick'
        }
      ]
    }
    reuseTerrButton = new HG.Button @_hgInstance, {
      'id':                 'reuseTerritory'
      'parentArea':         terrEditButtons
      'groupName':          'tt-edit-buttons'
      'states': [
        {
          'id':             'normal'
          'tooltip':        "Reuse territory from other times"
          'iconFA':         'plus'
          'callback':       'onClick'
        }
      ]
    }
    importTerrButton = new HG.Button @_hgInstance, {
      'id':                 'importTerritory'
      'parentArea':         terrEditButtons
      'groupName':          'tt-edit-buttons'
      'states': [
        {
          'id':             'normal'
          'tooltip':        "import territory from file"
          'iconFA':         'plus'
          'callback':       'onClick'
        }
      ]
    }


    ## 3. line: list of existing territories
    @_listTitle = new HG.Div null, ['tt-title', 'h2']
    @_listTitle.jq().html "Existing Territories"
    wrapper.append @_listTitle

    @_listWrapper = new HG.Div 'tt-list', null
    wrapper.append @_listWrapper

    # fill with dummy data
    @_addToList "this is a test territory"


    ## 4. line: snapping options
    # snap to points?, snap to lines? and snap tolerance
    snapTitle = new HG.Div null, ['tt-title', 'h2']
    snapTitle.jq().html "Snap Options"
    wrapper.append snapTitle

    # horizontal wrapper containing all three options
    snapOptionWrapper = new HG.Div 'tt-option-wrapper', null
    wrapper.append snapOptionWrapper

    # wrapper for each option containing input box + description
    snapToPointsWrapper = new HG.Div null, ['tt-snap-option-wrapper']
    snapOptionWrapper.append snapToPointsWrapper
    snapToLinesWrapper = new HG.Div null, ['tt-snap-option-wrapper']
    snapOptionWrapper.append snapToLinesWrapper
    snapToleranceWrapper = new HG.Div null, ['tt-snap-option-wrapper']
    snapOptionWrapper.append snapToleranceWrapper

    # snap to points
    snapToPointsCheckbox = new HG.Checkbox 'snapToPoints', ['tt-snap-option-checkbox']
    snapToPointsWrapper.append snapToPointsCheckbox
    snapToPointsText = new HG.Div null, ['tt-snap-option-text']
    snapToPointsText.jq().html "snap to border points"
    snapToPointsWrapper.append snapToPointsText

    # snap to lines
    snapToLinesCheckbox = new HG.Checkbox 'snapToLines', ['tt-snap-option-checkbox']
    snapToLinesWrapper.append snapToLinesCheckbox
    snapToLinesText = new HG.Div null, ['tt-snap-option-text']
    snapToLinesText.jq().html "snap to border lines"
    snapToLinesWrapper.append snapToLinesText

    # snap tolerance
    snapToleranceInput = new HG.NumberInput 'snapTolerance', ['tt-snap-option-input']
    snapToleranceInput.elem().setAttribute 'value', 9.3
    snapToleranceInput.elem().setAttribute 'maxlength', 3
    snapToleranceInput.elem().setAttribute 'step', 0.1
    snapToleranceInput.elem().setAttribute 'min', 0.0
    snapToleranceInput.elem().setAttribute 'max', 10.0
    snapToleranceWrapper.append snapToleranceInput
    snapToleranceText = new HG.Div null, ['tt-snap-option-text']
    snapToleranceText.jq().html "snap tolerance [px]"
    snapToleranceWrapper.append snapToleranceText


    # TODO: actual options

    ## 5. line: finish buttons
    # -> clip, use rest
    terrFinishButtons = new HG.ButtonArea @_hgInstance, {
      'id':                 'tt-finish-buttons'
      'classes':            ['tt-button-area']
      'parentDiv':          wrapper.elem()
      'absolutePosition':   false
    }

    clipAreasButton = new HG.Button @_hgInstance, {
      'id':                 'clipAreas'
      'parentArea':         terrFinishButtons
      'groupName':          'tt-finish-buttons'
      'states': [
        {
          'id':             'normal'
          'tooltip':        "Clip Selected Areas"
          'iconFA':         'check'
          'callback':       'onClick'
        }
      ]
    }
    terrFinishButtons.addSpacer 'tt-finish-buttons-group'

    useRestButton = new HG.Button @_hgInstance, {
      'id':                 'useRest'
      'parentArea':         terrFinishButtons
      'groupName':          'tt-finish-buttons'
      'states': [
        {
          'id':             'normal'
          'tooltip':        "Use The Rest as Territory for this Country"
          'iconFA':         'check'
          'callback':       'onClick'
        }
      ]
    }


  # ============================================================================


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _addToList: (text) ->
    newT = new HG.Div null, ['tt-list-entry']
    newT.jq().html text
    @_listWrapper.append newT