window.HG ?= {}

# ==============================================================================
# VIEW class
# set up and handle manipulating the geometry of one area
# approach:
#   use only leaflet draw and style the buttons
#   set up my own ButtonArea and move leaflet buttons in there
# ==============================================================================

class HG.NewGeometryTool

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

    @addCallback 'onSubmit'

    # includes
    @_map = @_hgInstance.map._map
    @_histoGraph = @_hgInstance.histoGraph
    @_geometryReader = new HG.GeometryReader
    @_geometryOperator = new HG.GeometryOperator

    iconPath = @_hgInstance._config.graphicsPath + 'buttons/'

    ### SETUP LEAFLET DRAW ###

    # group that contains all drawn territories
    @_polygons = new L.FeatureGroup
    @_map.addLayer @_polygons


    ### SETUP UI ###

    # leaflets draw control
    # TODO: restyling!
    @_drawControl = new L.Control.Draw {
        position: 'topright',
        draw: {
          polyline: no
          polygon: {
            shapeOptions : {
              # = focus mode on -> selected -> unfocused
              'className':    'new-geom-area'
              'fillColor':    HGConfig.color_active.val
              'fillOpacity':  HGConfig.area_half_opacity.val
              'color':        HGConfig.color_bg_dark.val
              'opacity':      HGConfig.border_opacity.val
              'weight':       HGConfig.border_width.val
            }
          }
          rectangle: no
          circle: no
          marker: no
        },
        edit: {
          featureGroup: @_polygons
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
      'id':           'newGeomButtons'
      'posX':         'right'
      'posY':         'top'
      'orientation':  'vertical'
    }
    @_hgInstance._top_area.appendChild @_buttonArea.getDom()


    ## buttons themselves

    @_newGeomBtn = new HG.Button @_hgInstance,
      'newGeom', null,
        [
          {
            'id':             'normal'
            'tooltip':        "Add new territory"
            'iconOwn':        iconPath + 'geom_add.svg'
            'callback':       'onClick'
          }
        ], @_transformToHGDOMElement leafletButtons[0]    # use existing leaflet "add polygon" button
    @_buttonArea.addButton @_newGeomBtn, 'new-geom-add-group'

    @_reuseGeomBtn = new HG.Button @_hgInstance,
      'reuseGeom', null,
        [
          {
            'id':             'normal'
            'tooltip':        "Reuse territory from other times"
            'iconOwn':        iconPath + 'geom_reuse.svg'
            'callback':       'onClick'
          }
        ]
    @_buttonArea.addButton @_reuseGeomBtn, 'new-geom-add-group'

    @_importGeomBtn = new HG.Button @_hgInstance,
      'importGeom', null,
        [
          {
            'id':             'normal'
            'tooltip':        "import territory from file"
            'iconOwn':        iconPath + 'geom_import.svg'
            'callback':       'onClick'
          }
        ]
    @_buttonArea.addButton @_importGeomBtn, 'new-geom-add-group'

    @_buttonArea.addSpacer()

    @_editGeomBtn = new HG.Button @_hgInstance,
      'editGeom', null,
        [
          {
            'id':             'normal'
            'tooltip':        "edit territory on the map"
            'iconFA':         'edit'
            'callback':       'onClick'
          }
        ], @_transformToHGDOMElement leafletButtons[1]    # use existing leaflet "edit polygon" button
    @_buttonArea.addButton @_editGeomBtn, 'new-geom-edit-group'

    @_deleteGeomBtn = new HG.Button @_hgInstance,
      'deleteGeom', null,
        [
          {
            'id':             'normal'
            'tooltip':        "delete territory on the map"
            'iconFA':         'trash-o'
            'callback':       'onClick'
          }
        ], @_transformToHGDOMElement leafletButtons[2]  # use existing leaflet "delete polygon" button
    @_buttonArea.addButton @_deleteGeomBtn, 'new-geom-edit-group'

    @_buttonArea.addSpacer()

    @_clipGeomBtn = new HG.Button @_hgInstance,
      'clipGeom', null,
        [
          {
            'id':             'normal'
            'tooltip':        "Clip Selected Areas"
            'iconOwn':        iconPath + 'polygon_cut.svg'
            'callback':       'onClick'
          }
        ]
    @_buttonArea.addButton @_clipGeomBtn, 'new-geom-finish-group'

    @_buttonArea.addSpacer()

    @_submitGeomBtn = new HG.Button @_hgInstance,
      'submitGeom', null,
        [
          {
            'id':             'normal'
            'tooltip':        "Accept current selection"
            'iconFA':         'check'
            # 'iconOwn':        iconPath + 'polygon_rest.svg'
            'callback':       'onClick'
          }
        ]
    @_buttonArea.addButton @_submitGeomBtn, 'new-geom-finish-group'

    # init configuration: only add buttons are available
    @_editGeomBtn.disable()
    @_deleteGeomBtn.disable()
    @_clipGeomBtn.disable()
    @_submitGeomBtn.disable()


    ### INTERACTION ###

    # handle change events on polygons
    @_map.on 'draw:created', @_createPolygon
    @_map.on 'draw:deleted', @_deletePolygon

    # click OK => submit geometry
    @_submitGeomBtn.onClick @, () =>

      geometries = []
      geometries.push @_geometryReader.read layer for layer in @_featureGroup.getLayers()
      # merge all of them together
      # -> only works if they are (poly)polygons, not for polylines or points

      @notifyAll 'onSubmit', @_geometryOperator.merge geometries

  # ============================================================================
  destroy: () ->

    # interaction
    @_map.off 'draw:created', @_createPolygon
    @_map.off 'draw:deleted', @_deletePolygon

    # UI
    @_buttonArea.destroy()
    @_map.removeControl @_drawControl
    delete @_drawControl
    @_map.removeLayer @_polygons
    delete @_polygons



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _createPolygon: (e) =>
    type = e.layerType
    layer = e.layer

    # put on the map
    @_polygons.addLayer layer

    # geometry can now be edited/deleted/submitted
    if @_polygons.getLayers().length is 1    # = if moved from 0 layers to 1 layer
      @_editGeomBtn.enable()
      @_deleteGeomBtn.enable()
      @_submitGeomBtn.enable()

  # ============================================================================
  _deletePolygon: (e) =>
    # geometry can not be edited/deleted/submitted anymore
    if @_polygons.getLayers().length is 0
      @_editGeomBtn.disable()
      @_deleteGeomBtn.disable()
      @_submitGeomBtn.disable()

  # ============================================================================
  _transformToHGDOMElement: (inButton) ->
    $(inButton).removeClass()
    $(inButton).detach()
    $(inButton).addClass 'button'
    new HG.Anchor null, null, null, inButton




# OLD CODE: snapping tools

  #   ## 4. line: snapping options
  #   # snap to points?, snap to lines? and snap tolerance

  #   # horizontal wrapper containing all three options
  #   snapOptionWrapper = new HG.Div 'tt-snap-option-wrapper-out', null
  #   @_wrapper.appendChild snapOptionWrapper

  #   # wrapper for each option containing input box + description
  #   snapToPointsWrapper = new HG.Div null, ['tt-snap-option-wrapper-in']
  #   snapOptionWrapper.appendChild snapToPointsWrapper
  #   snapToLinesWrapper = new HG.Div null, ['tt-snap-option-wrapper-in']
  #   snapOptionWrapper.appendChild snapToLinesWrapper
  #   snapToleranceWrapper = new HG.Div null, ['tt-snap-option-wrapper-in']
  #   snapOptionWrapper.appendChild snapToleranceWrapper

  #   # snap to points
  #   snapToPointsSwitch = new HG.Switch @_hgInstance, 'snapToPoints', ['tt-snap-option-switch']
  #   snapToPointsWrapper.appendChild snapToPointsSwitch
  #   snapToPointsText = new HG.Div null, ['tt-snap-option-text']
  #   snapToPointsText.j().html "snap to <br/>points"
  #   snapToPointsWrapper.appendChild snapToPointsText

  #   # snap to lines
  #   snapToLinesSwitch = new HG.Switch @_hgInstance, 'snapToLines', ['tt-snap-option-switch']
  #   snapToLinesWrapper.appendChild snapToLinesSwitch
  #   snapToLinesText = new HG.Div null, ['tt-snap-option-text']
  #   snapToLinesText.j().html "snap to <br/>lines"
  #   snapToLinesWrapper.appendChild snapToLinesText

  #   # snap tolerance
  #   snapToleranceInput = new HG.NumberInput @_hgInstance, 'snapTolerance', ['tt-snap-option-input']
  #   snapToleranceInput.dom().setAttribute 'value', 5.0
  #   snapToleranceInput.dom().setAttribute 'maxlength', 3
  #   snapToleranceInput.dom().setAttribute 'step', 0.1
  #   snapToleranceInput.dom().setAttribute 'min', 0.0
  #   snapToleranceInput.dom().setAttribute 'max', 10.0
  #   snapToleranceWrapper.appendChild snapToleranceInput
  #   snapToleranceText = new HG.Div null, ['tt-snap-option-text']
  #   snapToleranceText.j().html "snap <br/>tolerance"
  #   snapToleranceWrapper.appendChild snapToleranceText