window.HG ?= {}

# ==============================================================================
# MODEL
# HistoricalChange defines what has historically changed because of an Hivent.
# DTO => no functionality
#
# operations:
#   CRE) creation of new area:                         -> A
#   UNI) unification of many to one area:         A, B -> C
#   INC) incorporation of many into one area:     A, B -> A
#   SEP) separation of one into many areas:       A -> B, C
#   SEC) secession of many areas from one:        A -> A, B
#   NCH) name change of one or many areas:        A -> A', B -> B'
#   TCH) territory change of one or many areas:   A -> A', B -> B'
#   DES) destruction of an area:                  A ->
# ==============================================================================


class HG.HistoricalChange

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  constructor: (data)  ->
    @id             = data.id
    @operation      = data.operation
    @hivent         = data.hivent       # HG.Hivent
    @areaChanges    = []                # HG.AreaChange


  # ============================================================================
  # execute the change: visualize areas of interest and
  # then execute all its associated AreaChanges
  # ============================================================================

  execute: (direction) ->
    # +1: execute change forward
    # -1: execute change backward

    # TODO: visualize transition
    # switch @operation

    # execute all its changes
    for areaChange in @areaChanges
      areaChange.execute direction

