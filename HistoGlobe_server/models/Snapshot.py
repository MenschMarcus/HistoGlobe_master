# ==============================================================================
# Snapshot stores a complete image of all areas at a single moment in history
# -->  helpful for initialization of event-based spatio-temporal data model
#      and for reducing complexity in Area lookups
# ==============================================================================

#------------------------------------------------------------------------------
from django.utils import timezone
from django.db import models
import rfc3339


#------------------------------------------------------------------------------
class Snapshot(models.Model):
  date =        models.DateTimeField          (default=timezone.now)
  areas =       models.ManyToManyField        ('Area')

  def __unicode__(self):
    return rfc3339.rfc3339(self.date)

  class Meta:
    app_label = 'HistoGlobe_server'
    ordering = ['-date']        # descending order (2000 -> 0 -> -2000 -> ...)