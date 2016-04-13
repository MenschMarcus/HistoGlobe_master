# ==============================================================================
# An AreaChange is one explicit action part of an HistoricalChange and defines
# which areas are added, deleted or change their name or territory.
# An AreaChange relates to one specific area and has to specify also on creation
# and destruction which AreaName/AreaTerritory area new/old.
#
# ------------------------------------------------------------------------------
# AreaChange n:1 HistoricalChange
# AreaChange 2:1 Area
# AreaChange 2:2 AreaName
# AreaChange 2:2 AreaTerritory
#
# ------------------------------------------------------------------------------
# operations:
#   ADD) add new area:         -> A
#   DEL) delete old area:    A ->
#   NCH) name change:        A -> A
#   TCH) territory change:   A -> A
# ==============================================================================

from django.db import models


#------------------------------------------------------------------------------
class AreaChange(models.Model):

  historical_change   = models.ForeignKey ('HistoricalChange', related_name='historical_change')
  operation           = models.CharField  (default='XXX', max_length=3)
  area                = models.ForeignKey ('Area', related_name='change_area')
  old_area_name       = models.ForeignKey ('AreaName', related_name='new_area_name', null=True)
  new_area_name       = models.ForeignKey ('AreaName', related_name='old_area_name', null=True)
  old_area_territory  = models.ForeignKey ('AreaTerritory', related_name='new_area_territory', null=True)
  new_area_territory  = models.ForeignKey ('AreaTerritory', related_name='old_area_territory', null=True)

  def __unicode__(self):
    return '%s -> %s' % (self.hivent.name, self.operation)

  class Meta:
    app_label = 'HistoGlobe_server'