window.HG ?= {}

# ==============================================================================
# VIEW class
# set up and handle manipulating the geometry of one area
# approach:
#   use only leaflet draw and style the buttons
#   set up my own ButtonArea and move leaflet buttons in there
# ==============================================================================

class HG.NewCountryTerritory

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance) ->

    # add to HG instance
    @_hgInstance.newCountryTerritory = @

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onSubmitTerritory'

    # setup variables
    @_map = @_hgInstance.map._map
    @_histoGraph = @_hgInstance.histoGraph
    iconPath = @_hgInstance._config.graphicsPath + 'buttons/'


    ### SETUP LEAFLET DRAW ###

    # group that contains all drawn territories
    @_territories = new L.FeatureGroup
    @_map.addLayer @_territories


    ### SETUP UI ###

    # leaflets draw control
    # TODO: restyling!
    @_drawControl = new L.Control.Draw {
        position: 'topright',
        draw: {
          polyline: no
          polygon: yes
          rectangle: no
          circle: no
          marker: no
        },
        edit: {
          featureGroup: @_territories
        }
      }
    @_map.addControl @_drawControl

    # PROBLEM:
    # leaflet already has buttons to control the draw action
    # but I want them to behave just like any other HG Button
    # SOLUTION:
    # 1. extend the HG.DOMElement -> HG.Anchor class to also accept existing
    # dom elements and transform then into HG.DOMElements
    # 2. extend the HG.Button class to also accept existing HG.DOMElements as
    # parent divs for the button
    # -> very hacky, but elegant solution ;)

    # get the three leaflet control buttons
    # [0]: new polygon
    # [1]: edit polygon
    # [2]: delete polygon
    leafletButtons = $('.leaflet-draw a')

    # get the action tooltips from the control to align them to the new buttons
    # -> this is actually really really hacky hacky hacky
    $($('.leaflet-draw ul')[0]).attr 'id', 'leaflet-new-button-action'
    $($('.leaflet-draw ul')[1]).attr 'id', 'leaflet-edit-button-action'


    ## button area
    # -> leaflet buttons to be moved in there

    @_buttonArea = new HG.ButtonArea @_hgInstance, {
      'id':           'newTerritoryButtons'
      'positionX':    'right'
      'positionY':    'top'
      'orientation':  'vertical'
    }

    @_buttonArea.addButton new HG.Button(@_hgInstance, 'newTerritory', null, [
          {
            'id':             'normal'
            'tooltip':        "Add new territory"
            'iconOwn':        iconPath + 'geom_add.svg'
            'callback':       'onClick'
          }
        ], @_transformToHGDOMElement leafletButtons[0])   # use existing leaflet "new polygon" button
      ,'new-territory-add-group'

    @_buttonArea.addButton new HG.Button(@_hgInstance, 'reuseTerritory', null, [
        {
          'id':             'normal'
          'tooltip':        "Reuse territory from other times"
          'iconOwn':        iconPath + 'geom_reuse.svg'
          'callback':       'onClick'
        }
      ]), 'new-territory-add-group'

    @_buttonArea.addButton new HG.Button(@_hgInstance, 'importTerritory', null, [
        {
          'id':             'normal'
          'tooltip':        "import territory from file"
          'iconOwn':        iconPath + 'geom_import.svg'
          'callback':       'onClick'
        }
      ]), 'new-territory-add-group'

    @_buttonArea.addSpacer()

    @_buttonArea.addButton new HG.Button(@_hgInstance, 'editTerritory', null, [
          {
            'id':             'normal'
            'tooltip':        "edit territory on the map"
            'iconFA':         'edit'
            'callback':       'onClick'
          }
        ], @_transformToHGDOMElement leafletButtons[1])  # use existing leaflet "edit polygon" button
      ,'new-territory-edit-group'

    @_buttonArea.addButton new HG.Button(@_hgInstance, 'deleteTerritory', null, [
          {
            'id':             'normal'
            'tooltip':        "delete territory on the map"
            'iconFA':         'trash-o'
            'callback':       'onClick'
          }
        ], @_transformToHGDOMElement leafletButtons[2])  # use existing leaflet "delete polygon" button
      ,'new-territory-edit-group'

    @_buttonArea.addSpacer()

    @_buttonArea.addButton new HG.Button(@_hgInstance, 'clipTerritory', null, [
        {
          'id':             'normal'
          'tooltip':        "Clip Selected Areas"
          'iconOwn':        iconPath + 'polygon_cut.svg'
          'callback':       'onClick'
        }
      ]), 'new-territory-finish-group'

    @_buttonArea.addButton new HG.Button(@_hgInstance, 'useRest', null, [
        {
          'id':             'normal'
          'tooltip':        "Use The Rest as Territory for this Country"
          'iconOwn':        iconPath + 'polygon_rest.svg'
          'callback':       'onClick'
        }
      ]), 'new-territory-finish-group'



    ## styling = remove leaflet classes and append own class :P
    # 1. level (2 divs)
    # lev1 = $('.leaflet-draw').children()
    # $(lev1[0]).removeClass()
    # $(lev1[1]).removeClass()
    # lev20 = $(lev1[0]).children()[0]
    # lev21 = $(lev1[1]).children()[0]
    # # 2. level (1 div)
    # $(lev20).removeClass()
    # $(lev21).removeClass()
    # newPoly = $(lev20).children()[0]
    # editPoly = $(lev21).children()[0]
    # delPoly = $(lev21).children()[1]
    # # 3. level (3 a) -> actual buttons
    # $(newPoly).removeClass()
    # $(editPoly).removeClass()
    # $(delPoly).removeClass()
    # $(newPoly).attr 'id', 'newTerritory'
    # $(newPoly).addClass 'button leaflet-button'
    # $(newPoly).attr 'id', 'edit'
    # $(editPoly).addClass 'button leaflet-button'
    # $(delPoly).addClass 'button leaflet-button'


    ### INTERACTION ###

    # handle newly added polygons
    @_map.on 'draw:created', @_finishTerritory


  # ============================================================================
  destroy: () ->

    # interaction
    @_map.off 'draw:created', @_finishTerritory

    # UI
    @_map.removeControl @_drawControl
    delete @_drawControl
    @_map.removeLayer @_territories
    delete @_territories





  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _finishTerritory: (e) =>
    type = e.layerType
    layer = e.layer
    console.log e
    console.log layer._latlngs
    @_territories.addLayer layer
    layer.addTo @_map

  # ============================================================================
  _transformToHGDOMElement: (inButton) ->
    $(inButton).removeClass()
    $(inButton).detach()
    $(inButton).addClass 'button'
    new HG.Anchor null, null, null, inButton

    # # add button to button obAnject in HG instance
    # @_hgInstance.buttons[id] = @

    # # init states (each state has a configuration file)
    # stateConfig =
    #   id:         'normal'
    #   tooltip:    null
    #   iconFA:     null
    #   iconOwn:    null
    #   callback:   'onClick'













# OLD CODE: own territory tools
# -> use new one instead

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # constructor: (@_hgInstance) ->

  #   iconPath = @_hgInstance._config.graphicsPath + 'buttons/'

  #   ### INIT UI ###

  #   # moveable wrapper convering everything
  #   @_wrapper = new HG.Div 'tt-wrapper', null
  #   @_hgInstance._top_area.appendChild @_wrapper.dom()


  #   ## 1. line: title
  #   title = new HG.Div null, ['tt-title']
  #   title.j().html "Territory Tools"
  #   @_wrapper.append title


  #   ## 2. line: 3 buttons in a button area
  #   # -> new territory, reuse territory, import territory)
  #   terrEditButtons = new HG.ButtonArea @_hgInstance, {
  #     'id':                 'tt-edit-buttons'
  #     'classes':            ['tt-button-area']
  #     'parentDiv':          @_wrapper.dom()
  #     'absolutePosition':   false
  #   }

  #   terrEditButtons.addButton new HG.Button(@_hgInstance, 'newTerritory', null, [
  #       {
  #         'id':             'normal'
  #         'tooltip':        "Add new territory"
  #         'iconOwn':        iconPath + 'geom_add.svg'
  #         'callback':       'onClick'
  #       }
  #     ]), 'tt-edit-buttons-group'

  #   terrEditButtons.addButton new HG.Button(@_hgInstance, 'reuseTerritory', null, [
  #       {
  #         'id':             'normal'
  #         'tooltip':        "Reuse territory from other times"
  #         'iconOwn':        iconPath + 'geom_reuse.svg'
  #         'callback':       'onClick'
  #       }
  #     ]), 'tt-edit-buttons-group'

  #   terrEditButtons.addButton new HG.Button(@_hgInstance, 'importTerritory', null, [
  #       {
  #         'id':             'normal'
  #         'tooltip':        "import territory from file"
  #         'iconOwn':        iconPath + 'geom_import.svg'
  #         'callback':       'onClick'
  #       }
  #     ]), 'tt-edit-buttons-group'



  #   ## 3. line: list of existing territories
  #   @_listWrapper = new HG.Div 'tt-list', null
  #   @_wrapper.append @_listWrapper


  #   ## 4. line: snapping options
  #   # snap to points?, snap to lines? and snap tolerance

  #   # horizontal wrapper containing all three options
  #   snapOptionWrapper = new HG.Div 'tt-snap-option-wrapper-out', null
  #   @_wrapper.append snapOptionWrapper

  #   # wrapper for each option containing input box + description
  #   snapToPointsWrapper = new HG.Div null, ['tt-snap-option-wrapper-in']
  #   snapOptionWrapper.append snapToPointsWrapper
  #   snapToLinesWrapper = new HG.Div null, ['tt-snap-option-wrapper-in']
  #   snapOptionWrapper.append snapToLinesWrapper
  #   snapToleranceWrapper = new HG.Div null, ['tt-snap-option-wrapper-in']
  #   snapOptionWrapper.append snapToleranceWrapper

  #   # snap to points
  #   snapToPointsSwitch = new HG.Switch @_hgInstance, 'snapToPoints', ['tt-snap-option-switch']
  #   snapToPointsWrapper.append snapToPointsSwitch
  #   snapToPointsText = new HG.Div null, ['tt-snap-option-text']
  #   snapToPointsText.j().html "snap to <br/>points"
  #   snapToPointsWrapper.append snapToPointsText

  #   # snap to lines
  #   snapToLinesSwitch = new HG.Switch @_hgInstance, 'snapToLines', ['tt-snap-option-switch']
  #   snapToLinesWrapper.append snapToLinesSwitch
  #   snapToLinesText = new HG.Div null, ['tt-snap-option-text']
  #   snapToLinesText.j().html "snap to <br/>lines"
  #   snapToLinesWrapper.append snapToLinesText

  #   # snap tolerance
  #   snapToleranceInput = new HG.NumberInput @_hgInstance, 'snapTolerance', ['tt-snap-option-input']
  #   snapToleranceInput.dom().setAttribute 'value', 5.0
  #   snapToleranceInput.dom().setAttribute 'maxlength', 3
  #   snapToleranceInput.dom().setAttribute 'step', 0.1
  #   snapToleranceInput.dom().setAttribute 'min', 0.0
  #   snapToleranceInput.dom().setAttribute 'max', 10.0
  #   snapToleranceWrapper.append snapToleranceInput
  #   snapToleranceText = new HG.Div null, ['tt-snap-option-text']
  #   snapToleranceText.j().html "snap <br/>tolerance"
  #   snapToleranceWrapper.append snapToleranceText

  #   ## 5. line: finish buttons
  #   # -> clip, use rest
  #   terrFinishButtons = new HG.ButtonArea @_hgInstance, {
  #     'id':                 'tt-finish-buttons'
  #     'classes':            ['tt-button-area']
  #     'parentDiv':          @_wrapper.dom()
  #     'absolutePosition':   false
  #   }

  #   terrFinishButtons.addButton new HG.Button(@_hgInstance, 'clipTerritory', null, [
  #       {
  #         'id':             'normal'
  #         'tooltip':        "Clip Selected Areas"
  #         'iconOwn':        iconPath + 'polygon_cut.svg'
  #         'callback':       'onClick'
  #       }
  #     ]), 'tt-finish-buttons-group'

  #   terrFinishButtons.addSpacer 'tt-finish-buttons-group'

  #   terrFinishButtons.addButton new HG.Button(@_hgInstance, 'useRest', null, [
  #       {
  #         'id':             'normal'
  #         'tooltip':        "Use The Rest as Territory for this Country"
  #         'iconOwn':        iconPath + 'polygon_rest.svg'
  #         'callback':       'onClick'
  #       }
  #     ]), 'tt-finish-buttons-group'


  # # ============================================================================
  # destroy: () ->
  #   @_wrapper?.j().remove()
  #   delete @_wrapper?

  # # ============================================================================
  # addToList: (text) ->
  #   newT = new HG.Div null, ['tt-list-entry']
  #   newT.j().html text
  #   @_listWrapper.append newT

  # # ============================================================================
  # clearList: () ->
  #   @_listWrapper.empty()

  # ##############################################################################
  # #                            PRIVATE INTERFACE                               #
  # ##############################################################################

  # # ============================================================================