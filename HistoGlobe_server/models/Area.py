# ==============================================================================
# Area is the identity dimension of an Area: An integral area, that might change
# its territory or its common name, but not its formal name
# new Area <=> new formal name
# ChangeArea.old_area 1:1 Area, ChangeArea.new_area 1:1 Area
# access predecessors and successors via start_/end_change
# ==============================================================================

#------------------------------------------------------------------------------
from django.db import models

#------------------------------------------------------------------------------
class Area(models.Model):
  start_change =          models.ForeignKey         ('Change', related_name='area_start_change', null=True)
  end_change =            models.ForeignKey         ('Change', related_name='area_end_change', null=True)

  def __unicode__(self):
    return str(self.id)

  class Meta:
    app_label = 'HistoGlobe_server'