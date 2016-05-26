# ==============================================================================
# An HistoricalChange is one high-level change that has occured to a set of
# Areas in history. It is created by one explicit Edit Operation and belongs to
# exactly one Hivent.
# A set of AreaChanges will be referenced to this HistoricalChange
#
# ------------------------------------------------------------------------------
# HistoricalChange n:1 Hivent
#
# ------------------------------------------------------------------------------
# operations:
#   CRE) Create
#   MRG) Merge
#   DIS) Dissolve
#   CHB) Change Borders
#   REN) Rename
#   CES) Cease
# ==============================================================================


from django.db import models
from django.utils import timezone
from django.contrib import gis
from djgeojson.fields import *
from django.forms.models import model_to_dict

# ==============================================================================
class HistoricalChange(models.Model):

  # superordinate: Hivent
  hivent            = models.ForeignKey ('Hivent', related_name='change_hivent')

  # own attribute:
  edit_operation    = models.CharField  (default='XXX', max_length=3)

  # ----------------------------------------------------------------------------
  def __unicode__(self):
    return self.operation

  # ----------------------------------------------------------------------------
  class Meta:
    app_label = 'HistoGlobe_server'
