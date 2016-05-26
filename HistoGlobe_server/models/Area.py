# ==============================================================================
# An Area represents a political entitry (e.g. country, state, province,
# overseas territory, ...) with a specific identity in history. It has an
# AreaName and an AreaTerritory attached to at any givent point in history.
# The short / common name and the territory of an area can change without
# changing the identity of the Area. However, as soon as the formal name changes
# it becomes a new Area.
#
# ------------------------------------------------------------------------------
# Area n:2 AreaChange
# Area 1:n AreaName
# Area 1:n AreaTerritory
#
# ==============================================================================


from django.db import models
from django.forms.models import model_to_dict

# ==============================================================================
class Area(models.Model):

  # superordinate: AreaChange (historical context)
  start_change =          models.ForeignKey         ('AreaChange', related_name='start_change', null=True)
  end_change =            models.ForeignKey         ('AreaChange', related_name='end_change', null=True)

  # own attribute
  universe =              models.BooleanField       (default=False)

  # ----------------------------------------------------------------------------
  def __unicode__(self):
    return str(self.id)

  # ----------------------------------------------------------------------------
  class Meta:
    app_label = 'HistoGlobe_server'