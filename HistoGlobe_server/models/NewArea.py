# ==============================================================================
# A NewArea is one specific Area + AreaName + AreaTerritory that starts
# due to exactly one AreaChange.
#
# ------------------------------------------------------------------------------
# NewArea n:1 AreaChange
# NewArea 1:1 Area
# NewArea 1:1 AreaName
# NewArea 1:1 AreaTerritory
# ==============================================================================


from django.db import models
from django.forms.models import model_to_dict

# ==============================================================================
class NewArea(models.Model):

  # superordinate: AreaChange
  area_change   = models.ForeignKey ('AreaChange', related_name='new_area_change', default=0)

  # own attributes
  area          = models.ForeignKey ('Area', related_name='new_area', default=0)
  name          = models.ForeignKey ('AreaName', related_name='new_area_name', default=0)
  territory     = models.ForeignKey ('AreaTerritory', related_name='new_area_territory', default=0)

  # ----------------------------------------------------------------------------
  def __unicode__(self):
    return self.name.short_name

  # ----------------------------------------------------------------------------
  class Meta:
    app_label = 'HistoGlobe_server'