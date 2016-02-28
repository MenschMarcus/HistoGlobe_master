window.HG ?= {}

window.HG.Database ?= {}

class HG.HiventDatabaseInterface

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (serverName, databaseName) ->
    @_serverName = serverName
    @_databaseName = databaseName

  # ============================================================================
  # config =
  #   tableName: string -- name of the table
  #   selector: string -- mysql selector such as *
  #   condition: string -- mysql condition such as id == H1
  #   lowerLimit: int -- minum number of hivents to fetch
  #   upperLimit: int -- maximum number of hivents to fetch
  #   success: function -- triggered when fetching was successful

  getHivents: (config) =>

    if (config.tableName?)

      config.condition?= ""
      config.selector?= "*"
      config.lowerLimit?= 0
      config.upperLimit?= 1

      config.success?= (data) -> console.log data

      $.ajax({
          url: "php/query_database.php?" +
                "serverName=#{@_serverName}" +
                "&dbName=#{@_databaseName}" +
                "&tableName=#{config.tableName}" +
                "&lowerLimit=#{config.lowerLimit}" +
                "&upperLimit=#{config.upperLimit}" +
                "&condition=#{config.condition}" +
                "&selector=#{config.selector}",
          type: "GET",
          success: config.success
        })
    else
      console.error "Unable to get hivents: No table name specified!"

# ============================================================================
  # config =
  #   tableName: string -- name of the table
  #   hivents: Array() -- hivents to be added
  #   success: function -- triggered for each successfully added hivent

  addHivents: (config) =>

    if (config.tableName?)

      if (config.hivents? and config.hivents.length > 0)

        config.success?= (data) -> console.log data if data != ""

        for hivent in config.hivents
          $.ajax({
              url: "php/add_hivent.php?" +
                    "serverName=#{@_serverName}" +
                    "&dbName=#{@_databaseName}" +
                    "&tableName=#{config.tableName}"
              type: "POST",
              data: hivent,
              success: config.success
            })
      else
        console.error "Unable to add hivents: No hivents given!"
    else
      console.error "Unable to add hivents: No table name specified!"

# ============================================================================
  # config =
  #   tableName: string -- name of the table
  #   hivents: Array() -- hivents to be removed
  #   success: function -- triggered for each successfully removed hivent

  removeHivents: (config) =>

    if (config.tableName?)

      if (config.hivents? and config.hivents.length > 0)

        config.success?= (data) -> console.log data if data != ""

        for hivent in config.hivents
          $.ajax({
              url: "php/remove_from_database.php?" +
                    "serverName=#{@_serverName}" +
                    "&dbName=#{@_databaseName}" +
                    "&tableName=#{config.tableName}" +
                    "&condition=id=\"#{hivent.id}\""
              type: "GET"
              success: config.success
            })
      else
        console.error "Unable to remove hivents: No hivents given!"
    else
      console.error "Unable to remove hivents: No table name specified!"
