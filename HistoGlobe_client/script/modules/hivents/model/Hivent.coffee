window.HG ?= {}

# ==============================================================================
# MODEL
# Hivent is used as a simple data transfer object and stores all information
# belonging to a specific historical event.
# ==============================================================================

class HG.Hivent

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  constructor: (data)  ->
    @id             = data.id
    @name           = data.name
    @startDate      = data.startDate
    @endDate        = data.endDate
    @effectDate     = data.effectDate
    @secessionDate  = data.secessionDate
    @displayDate    = data.displayDate
    @locationName   = data.locationName
    @locationPoint  = data.locationPoint
    @locationArea   = data.locationArea
    @description    = data.description
    @linkUrl        = data.linkUrl
    @linkDate       = data.linkDate
    @changes        = data.changes