# ==============================================================================
# An HistoricalChange belongs to an Hivent and defines what has historically
# changed because of that Hivent.
#
# ------------------------------------------------------------------------------
# Hivent 1:n HistoricalChange
#
# ------------------------------------------------------------------------------
# operations:
#   CRE) creation of new area:                         -> A
#   UNI) unification of many to one area:         A, B -> C
#   INC) incorporation of many into one area:     A, B -> A
#   SEP) separation of one into many areas:       A -> B, C
#   SEC) secession of many areas from one:        A -> A, B
#   NCH) name change of one or many areas:        A -> A', B -> B'
#   TCH) territory change of one or many areas:   A -> A', B -> B'
#   DES) destruction of an area:                  A ->
# ==============================================================================

from django.db import models
from django.utils import timezone
from django.contrib import gis
from djgeojson.fields import *


#------------------------------------------------------------------------------
class HistoricalChange(models.Model):

  hivent            = models.ForeignKey ('Hivent', related_name='change_hivent')
  operation         = models.CharField  (default='XXX', max_length=3)

  def __unicode__(self):
    return self.operation

  class Meta:
    app_label = 'HistoGlobe_server'
