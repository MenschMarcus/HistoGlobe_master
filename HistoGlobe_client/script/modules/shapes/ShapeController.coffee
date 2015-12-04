window.HG ?= {}

class HG.ShapeController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # @addCallback "onShowShape"
    # @addCallback "onHideshape"

    @_shapes = []
    @_timeline = null
    @_now = null

    @_categoryFilter =null
    @_currentCategoryFilter = null

    defaultConfig =
      shapeJSONPaths: undefined,

    conf = $.extend {}, defaultConfig, config

    @loadShapesFromJSON conf

  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.ShapeController = @

    @_timeline = hgInstance.timeline
    @_shape_styler = hgInstance.shapeStyler
    @_now = @_timeline.getNowDate()

    # quicky...
    @_map = hgInstance.map._map

    @_timeline.onNowChanged @, (date) ->
      @_now = date
      for shape in @_shapes
        # shape.setDate date
        @_filterShapeTimeQuicky shape

    hgInstance.categoryFilter?.onFilterChanged @,(categoryFilter) =>
      @_currentCategoryFilter = categoryFilter
      @_filterActiveShapes()

    @_categoryFilter = hgInstance.categoryFilter if hgInstance.categoryFilter

  # ============================================================================
  loadShapesFromJSON: (config) ->

    for path in config.shapeJSONPaths
      $.getJSON path, (shapes) =>
        shapes_to_load = shapes.elements.length
        for shape in shapes.elements

          execute_async = (c) =>
            setTimeout () =>

              # quicky...
              circle = L.circle [c.center[1], c.center[0]], c.size*1000,
                color: '#666'
                opacity: 1
                weight: 2
                fillColor: '#fc0'
                fillOpacity: 1

              circle.bindLabel(c.label)
              circle.myData = c
              circle.myData.startDate = @_timeline.stringToDate c.start
              circle.myData.endDate = @_timeline.stringToDate c.end

              @_shapes.push circle



              # newShape = new HG.Shape c

              # newShape.onShow @, (shape) =>
              #   @notifyAll "onShowShape", shape
              #   shape.isVisible = true

              # newShape.onHide @, (shape) =>
              #   @notifyAll "onHideshape", shape
              #   shape.isVisible = false

              # @_shapes.push newShape

              # newShape.setDate @_now

              shapes_to_load--
              if shapes_to_load is 0
                @_currentCategoryFilter = @_categoryFilter.getCurrentFilter()
                @_filterActiveShapes()

            , 0

          execute_async shape

  # ============================================================================
  _filterActiveShapes:()->

    activeShapes = @getAllShapes()
    # activeShapes = @getActiveShapes()

    for shape in activeShapes
      active = false
      # for category in shape.getCategories()
      for category in shape.myData.categories
        if category in @_currentCategoryFilter
          active = true
      if active
        # @notifyAll "onShowShape", shape if not shape.isVisible
        # shape.setDate @_now
        shape.isVisible = true
        @_filterShapeTimeQuicky shape
      else
        # @notifyAll "onHideshape", shape
        shape.isVisible = false
        @_map.removeLayer shape

  # ============================================================================
  filterShape:()->
    # for category in shape.getCategories()
    for category in shape.myData.categories
      if category in @_currentCategoryFilter
        return true
    return false

  # ============================================================================
  getActiveShapes:()->
    newArray = []
    for a in @_shapes
      if a._active
        newArray.push a
    return newArray


  # ============================================================================
  getAllShapes:()->
    return @_shapes

  # ============================================================================
  _filterShapeTimeQuicky:(shape) ->
    if shape.isVisible
      if shape.myData.startDate <= @_now and shape.myData.endDate > @_now
        @_map.addLayer shape
      else
        @_map.removeLayer shape
