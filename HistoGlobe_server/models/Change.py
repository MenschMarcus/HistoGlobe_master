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
class Change(models.Model):
  hivent =      models.ForeignKey ('Hivent', related_name='hivent')
  operation =   models.CharField  (default='XXX', max_length=3)

  def __unicode__(self):
    return '%s -> %s' % (self.hivent.name, self.operation)

  class Meta:
    app_label = 'HistoGlobe_server'