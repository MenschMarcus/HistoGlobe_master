window.HG ?= {}

# ==============================================================================
# Hivent is used as a simple data transfer object and stores all information
# belonging to a specific historical event.
# ==============================================================================
class HG.Hivent

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  constructor: (
      @_id, @_name,
      @_startYear, @_startMonth, @_startDay,
      @_endYear, @_endMonth, @_endDay,
      displayDate,
      @_locationName,
      @_long, @_lat, @_region,
      @_isImp,
      @_category, @_parentTopic, @_subTopic
      @_content,
      @_description, @_multimedia, @_link
    )  ->

    @startDate = new Date(startYear, startMonth - 1, startDay)
    @endDate = new Date(endYear, endMonth - 1, endDay)
    @displayDate = displayDate ?= new String (@startDate + " bis " + @endDate)