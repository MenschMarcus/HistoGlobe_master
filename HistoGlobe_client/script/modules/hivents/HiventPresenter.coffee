window.HG ?= {}

class HG.HiventPresenter

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  hgInit: (@_hgInstance) ->
    @_hgInstance.hiventPresenter = @

    @_hgInstance.onAllModulesLoaded @, () =>
      @_timeline            = @_hgInstance.timeline
      @_hiventController    = @_hgInstance.hiventController
      @_hiventInfoPopovers  = @_hgInstance.hiventInfoPopovers

  # ============================================================================
  present: (id) ->
    if @_hiventController?
      @_hiventController.getHivents @, (handle) =>
        if handle.getHivent().id is id
          @_timeline.moveToDate handle.getHivent().startDate, 0.5
          @_hiventController.removeListener "onHiventAdded", @

    if @_hiventInfoPopovers?
      @_hiventInfoPopovers.getPopovers @, (marker) =>
        handle = marker.getHiventHandle()
        hivent = handle.getHivent()
        if hivent.id is id
          handle.focusAll()
          handle.activeAll()
          @_hiventInfoPopovers.removeListener "onPopoverAdded", @

