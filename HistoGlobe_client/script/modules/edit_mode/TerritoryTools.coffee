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
    @_wrapper = new HG.Div 'tt-wrapper', null
    @_hgInstance._top_area.appendChild @_wrapper.obj()


    ## 1. line: title
    @_title = new HG.Div null, ['tt-title', 'h1']
    @_title.dom().html "Territory Tools"
    @_wrapper.append @_title


    ## 2. line: 3 buttons in a button area
    # -> new territory, reuse territory, import territory)
    @_terrEditButtons = new HG.ButtonArea @_hgInstance, {
      'id':                 'tt-edit-buttons'
      'classes':            ['tt-button-area']
      'parentDiv':          @_wrapper.obj()
      'absolutePosition':   false
    }

    @_newTerrButton = new HG.Button @_hgInstance, {
      'id':                 'newTerritory'
      'parentArea':         @_terrEditButtons
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

    @_reuseTerrButton = new HG.Button @_hgInstance, {
      'id':                 'reuseTerritory'
      'parentArea':         @_terrEditButtons
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

    @_importTerrButton = new HG.Button @_hgInstance, {
      'id':                 'importTerritory'
      'parentArea':         @_terrEditButtons
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
    @_listTitle.dom().html "Existing Territories"
    @_wrapper.append @_listTitle

    @_listWrapper = new HG.Div 'tt-list', null
    @_wrapper.append @_listWrapper

    # fill with dummy data
    @addToList "this is a test territory"


    ## 4. line: snapping options
    @_snapTitle = new HG.Div null, ['tt-title', 'h2']
    @_snapTitle.dom().html "Snap Options"
    @_wrapper.append @_snapTitle

    # TODO: actual options

    ## 5. line: finish buttons
    # -> clip, use rest
    @_terrFinishButtons = new HG.ButtonArea @_hgInstance, {
      'id':                 'tt-finish-buttons'
      'classes':            ['tt-button-area']
      'parentDiv':          @_wrapper.obj()
      'absolutePosition':   false
    }

    @_clipAreasButton = new HG.Button @_hgInstance, {
      'id':                 'clipAreas'
      'parentArea':         @_terrFinishButtons
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
    @_terrFinishButtons.addSpacer 'tt-finish-buttons-group'

    @_useRestButton = new HG.Button @_hgInstance, {
      'id':                 'useRest'
      'parentArea':         @_terrFinishButtons
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
  addToList: (text) ->
    newT = new HG.Div null, ['tt-list-entry']
    newT.dom().html text
    @_listWrapper.append newT


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================