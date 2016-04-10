# ==============================================================================
# ChangeAreaTerritories stores one explicit change of Area names (no id change)
# (0/1 old AreaTerritory -> 0/1 new AreaTerritory)
# Change 1:n ChangeAreaTerritories
#
# ------------------------------------------------------------------------------
# operations:
#   ADD) add new area:      0 -> A
#   UNI) unification:       A -> 0, B -> 0, 0 -> C
#   INC) incorporation:     B -> 0, A -> A'
#   SEP) separation:        A -> 0, 0 -> B, 0 -> C
#   SEC) secession:         0 -> B, A -> A'
#   NCH) name change:
#   ICH) identity change:
#   DEL) delete area:       A -> 0
# ==============================================================================

#------------------------------------------------------------------------------
from django.db import models


#------------------------------------------------------------------------------
class ChangeAreaTerritories(models.Model):
  change =              models.ForeignKey ('Change',        related_name='territories_change')
  old_area_territory =  models.ForeignKey ('AreaTerritory', related_name='territories_old_area', null=True)
  new_area_territory =  models.ForeignKey ('AreaTerritory', related_name='territories_new_area', null=True)

  def __unicode__(self):
    return self.change.operation

  class Meta:
    app_label = 'HistoGlobe_server'
