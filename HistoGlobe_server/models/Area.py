# ==============================================================================
# Area is the identity dimension of an Area: An integral area, that might change
# its territory or its common name, but not its formal name
# new Area <=> new formal name
# ChangeArea.old_area 1:1 Area, ChangeArea.new_area 1:1 Area
# access predecessors and successors via start_/end_change
# ==============================================================================

# ------------------------------------------------------------------------------
from django.db import models

# ------------------------------------------------------------------------------
class Area(models.Model):
  start_change =          models.ForeignKey         ('Change', related_name='area_start_change', null=True)
  end_change =            models.ForeignKey         ('Change', related_name='area_end_change', null=True)


  # ----------------------------------------------------------------------------
  def __unicode__(self):
    return str(self.id)


  # ----------------------------------------------------------------------------
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

