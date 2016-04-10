# ==============================================================================
# ChangeAreaNames stores one explicit change of Area names (no id change)
# (0/1 old AreaName -> 0/1 new AreaName)
# Change 1:n ChangeAreaNames
#
# ------------------------------------------------------------------------------
# operations:
#   ADD) add new area:      0 -> A
#   UNI) unification:       A -> 0, B -> 0, 0 -> C
#   INC) incorporation:     B -> 0
#   SEP) separation:        A -> 0, 0 -> B, 0 -> C
#   SEC) secession:         0 -> B
#   NCH) name change:       A -> A'
#   ICH) identity change:   A -> 0, 0 -> B
#   DEL) delete area:       A -> 0
# ==============================================================================

#------------------------------------------------------------------------------
from django.db import models

#------------------------------------------------------------------------------
class ChangeAreaNames(models.Model):
  change =              models.ForeignKey ('Change',   related_name='names_change')
  old_area_name =       models.ForeignKey ('AreaName', related_name='names_old_area', null=True)
  new_area_name =       models.ForeignKey ('AreaName', related_name='names_new_area', null=True)

  def __unicode__(self):
    return self.change.operation

  class Meta:
    app_label = 'HistoGlobe_server'