# ==============================================================================
# ChangeAreas stores one explicit change of Areas (id!)
# (0/1 old Area -> 0/1 new Area)
# Change 1:n ChangeAreas
#
# ------------------------------------------------------------------------------
# operations:
#   ADD) add new area:      0 -> A
#   UNI) unification:       A -> C, B -> C
#   INC) incorporation:     B -> A
#   SEP) separation:        A -> B, A -> C
#   SEC) secession:         A -> B
#   NCH) name change:
#   ICH) identity change:   A -> B
#   DEL) delete area:       A -> 0
#
# ------------------------------------------------------------------------------
# TODO: 'historical descendant' to create hierarchy of countries?
#   e.g. unified Germany if a descendant of West and East Germany
#   West Germany was a descendant of Nazi Germany, but East Germany formally was not -> "new country"
# ==============================================================================

#------------------------------------------------------------------------------
from django.db import models


#------------------------------------------------------------------------------
class ChangeAreas(models.Model):
  change =              models.ForeignKey ('Change', related_name='areas_change')
  old_area =            models.ForeignKey ('Area',   related_name='areas_old_area', null=True)
  new_area =            models.ForeignKey ('Area',   related_name='areas_new_area', null=True)

  def __unicode__(self):
    return self.change.operation

  class Meta:
    app_label = 'HistoGlobe_server'