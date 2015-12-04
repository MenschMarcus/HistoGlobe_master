window.HG ?= {}

class HG.LabelController

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (timeline) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onShowLabel"
    @addCallback "onHideLabel"

    @_initMembers()

    #timeline.addListener this

  # ============================================================================
  nowChanged: (date) ->
    @_now = date
    for label in @_labels
      label.setDate date

  # ============================================================================
  periodChanged: (dateA, dateB) ->

  # ============================================================================
  categoryChanged: (c) ->


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initMembers: ->
    @_labels = []
    @_now = new Date(2000, 1, 1)

    @_loadJson "data/label_collection.json"

  # ============================================================================
  _loadJson: (file) ->
    $.getJSON file, (labels) =>
      for label in labels
        newLabels = new HG.Label label

        newLabels.onShow @, (area) =>
          @notifyAll "onShowLabel", area

        newLabels.onHide @, (area) =>
          @notifyAll "onHideLabel", area

        @_labels.push newLabels

        newLabels.setDate @_now

