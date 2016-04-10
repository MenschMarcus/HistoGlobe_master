# ==============================================================================
# TerritoryRelation stores relations between a homeland (e.g. France) and its
# (overseas) territory with a certain status (e.g. 'colony' or 'free association')
# ==============================================================================

#------------------------------------------------------------------------------
from django.db import models


#------------------------------------------------------------------------------
class TerritoryRelation(models.Model):
  sovereignt =            models.ForeignKey         ('Area', related_name='sovereignt', default=0)
  dependency =            models.ForeignKey         ('Area', related_name='dependency', default=0)
  # type =                models.CharField          (max_lengthh=20, default='territory')

  class Meta:
    app_label = 'HistoGlobe_server'