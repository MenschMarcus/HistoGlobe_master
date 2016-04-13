# ==============================================================================
# An Area represents an administrative unit (e.g. country, state, province,
# overseas territory, ...) with a specific identity in history. It has an
# AreaName and an AreaTerritory attached at any givent point in history.
# The short / common name and the territory of an area can change without
# changing the identity of the Area. However, as soon as the formal name changes
# it becomes a new Area.
#
# ------------------------------------------------------------------------------
# Area 1:2 AreaChange
# Area 1:n AreaName
# Area 1:n AreaTerritory
# Area 2:n TerritoryRelation
#
# ==============================================================================

from django.db import models


# ------------------------------------------------------------------------------
class Area(models.Model):

  start_change =          models.ForeignKey         ('AreaChange', related_name='start_change', null=True)
  end_change =            models.ForeignKey         ('AreaChange', related_name='end_change', null=True)


  # ----------------------------------------------------------------------------
  def __unicode__(self):
    return str(self.id)


  # ============================================================================
  # The historical predecessors and successors can be accessed like this:
  # The start / end_change (AreaChange) of the Area belong to an HistoricalChange.
  # This HistoricalChange contains of several AreaChanges.
  #
  #   predecessors: Area(start_change)            --(1)->
  #                 AreaChange(historical_change) --(1)->
  #                 HistoricalChange()            <-(n)--
  #                 AreaChange(historical_change)
  #
  #   successors:   Area(end_change)              --(1)->
  #                 AreaChange(historical_change) --(1)->
  #                 HistoricalChange()            <-(n)--
  #                 AreaChange(historical_change)
  # ============================================================================

  def get_predecessors(self):
    "Returns the historical ancestors (predecessors) of the area"

    from HistoGlobe_server.models import ChangeAreas

    try:
      predecessors = ChangeAreas.objects.filter(new_area=self).value('old_area')
    except:
      predecessors = []

    return predecessors


  # ----------------------------------------------------------------------------
  def get_successors(self):
    "Returns the historical decendents (successors) of the area"

    from HistoGlobe_server.models import ChangeAreas

    try:
      successors = ChangeAreas.objects.filter(old_area=self).value('new_area')
    except:
      successors = []

    return successors


  # ============================================================================
  # The territorial relations of the areas (sovereignt <-(1)-(n)-> dependency)
  # can be accessed via the TerritorialRelation entity.
  # ============================================================================

  def get_sovereignt(self):
    "Returns the areas sovereignt (where this area is a dependency)."

    from HistoGlobe_server.models import TerritoryRelations

    return TerritoryRelations.objects.get(dependency=self).sovereignt.id


  # ----------------------------------------------------------------------------
  def get_dependencies(self):
    "Returns the areas dependencies (where this area is the sovereignt)."

    from HistoGlobe_server.models import TerritoryRelations

    dependencies = []
    for dependency in TerritoryRelations.objects.filter(sovereignt=self):
      dependencies.append(dependency.id)

    return dependencies


  # ----------------------------------------------------------------------------
  class Meta:
    app_label = 'HistoGlobe_server'

