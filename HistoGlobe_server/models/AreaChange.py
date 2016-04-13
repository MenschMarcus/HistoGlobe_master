# ==============================================================================
# A change belongs to an Hivent and defines an explicit change of Areas
# Hivent 1:n Change
#
# ------------------------------------------------------------------------------
# operations:
#   ADD) add new area:      0 -> A
#   UNI) unification:       A, B -> C
#   INC) incorporation:     A, B -> A
#   SEP) separation:        A -> B, C
#   SEC) secession:         A -> A, B
#   NCH) name change:       A -> A
#   ICH) identity change:   A -> B
#   DEL) delete area:       A -> 0
# ==============================================================================

#------------------------------------------------------------------------------
from django.db import models


#------------------------------------------------------------------------------
class AreaChange(models.Model):

  hivent              = models.ForeignKey ('Hivent', related_name='change_hivent')
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