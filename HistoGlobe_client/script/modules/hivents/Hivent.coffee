window.HG ?= {}

# ==============================================================================
# Hivent is used as a simple data transfer object and stores all information
# belonging to a specific historical event.
# ==============================================================================
class HG.Hivent

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  constructor: (data)  ->
    @id           = data.id
    @name         = data.name
    @startDate    = new Date(data.startYear, data.startMonth-1, data.startDay)
    @endDate      = new Date(data.endYear, data.endMonth-1, data.endDay)
    @displayDate  = data.displayDate ?= new String (@startDate + " &ndash; " + @endDate)
    @locationName = data.locationName
    @long         = data.lng
    @lat          = data.lat
    @region       = data.region
    @isImp        = data.isImp
    @category     = data.category
    @parentTopic  = data.parentTopic
    @subTopic     = data.subTopic
    @content      = data.content
    @description  = data.description
    @multimedia   = data.multimedia
    @link         = data.link