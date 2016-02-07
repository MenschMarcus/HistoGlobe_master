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
      'parentDiv':    @_hgInstance.timeline.getParentDiv().obj(),
      'positionX':    'left',
      'positionY':    'right',
      'orientation':  'horizontal'
    }

    # buttons itself
    zoomOutButton = new HG.Button @_hgInstance,
    {
      'parentArea':   zoomButtonsArea,
      'groupName':    'timelineZoom'
      'id':           'timelineZoomOut',
      'states': [
        'id':         'normal',
        'tooltip':    "Zoom Out Timeline",
        'iconFA':     'minus'
        'callback':   'onClick'
      ]
    }
    zoomInButton = new HG.Button @_hgInstance,
    {
      'parentArea':   zoomButtonsArea,
      'groupName':    'timelineZoom'
      'id':           'timelineZoomIn',
      'states': [
        'id':         'normal',
        'tooltip':    "Zoom In Timeline",
        'iconFA':     'plus'
        'callback':   'onClick'
      ]
    }