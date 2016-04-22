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
from django.forms.models import model_to_dict


# ------------------------------------------------------------------------------
class Area(models.Model):

  # no properties except for id

  # historical context
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


  # ----------------------------------------------------------------------------
  class Meta:
    app_label = 'HistoGlobe_server'

