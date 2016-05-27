window.HG ?= {}

# ==============================================================================
# MODEL
# Hivent stores all information belonging to a specific historical event.
# DTO => no functionality
# ==============================================================================

class HG.Hivent

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  constructor: (data)  ->
    @id                 = data.id

    # superordinate: HiventHandle
    @handle             = null  # HG.HiventHandle

    # properties
    @name               = data.name
    @date               = data.date
    @location           = data.location
    @description        = data.description
    @link               = data.link

    # subordinate: HistoricalChanges
    @historicalChanges  = []     # HG.HistoricalChange