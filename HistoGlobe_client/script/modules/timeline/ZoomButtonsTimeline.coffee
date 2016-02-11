window.HG ?= {}

class HG.ZoomButtonsTimeline

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance) ->

    # button area
    zoomButtonsArea = new HG.ButtonArea @_hgInstance,
    {
      'id':           'timeline-zoom-buttons',
      'parentDiv':    @_hgInstance.timeline.getParentDiv().dom(),
      'positionX':    'left',
      'positionY':    'right',
      'orientation':  'horizontal'
    }

    # buttons itself
    zoomButtonsArea.addButton new HG.Button @_hgInstance, 'timelineZoomOut', null, [
        {
          'id':         'normal',
          'tooltip':    "Zoom Out Timeline",
          'iconFA':     'minus'
          'callback':   'onClick'
        }
      ], 'timelineZoom'

    zoomButtonsArea.addButton new HG.Button @_hgInstance, 'timelineZoomIn', null, [
        {
          'id':         'normal',
          'tooltip':    "Zoom In Timeline",
          'iconFA':     'plus'
          'callback':   'onClick'
        }
      ], 'timelineZoom'
