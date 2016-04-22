# ==============================================================================
# AreaTerritory stores the spatial dimension of an Area.
#
# ------------------------------------------------------------------------------
# AreaTerritory n:1 Area
#
# ------------------------------------------------------------------------------
#
# TODO: calculate reasonable name position with intelligent algorithm
# ==============================================================================

from django.db import models
from django.contrib import gis
from djgeojson.fields import *
from django.forms.models import model_to_dict

#------------------------------------------------------------------------------
class AreaTerritory(models.Model):

  # superordinate: Area
  area =                  models.ForeignKey               ('Area',   related_name='territory_area', default='0')

  # properties
  geometry =              gis.db.models.MultiPolygonField (default='MULTIPOLYGON EMPTY')
  representative_point =  gis.db.models.PointField        (null=True)

  # historical context
  start_change =          models.ForeignKey               ('AreaChange', related_name='territory_start_change', null=True)
  end_change =            models.ForeignKey               ('AreaChange', related_name='territory_end_change', null=True)

  # overriding the default manager with a GeoManager instance.
  # didn't quite understand what this is for...
  objects =               gis.db.models.GeoManager        ()

  # ============================================================================
  def __unicode__(self):
    return str(self.id)

  # ============================================================================
  # make territory ready to output (use wkt string of geometry)
  # ============================================================================

  def prepare_output(self):

    start_change = None
    end_change = None
    if self.start_change:
      start_change = self.start_change.id
    if self.end_change:
      end_change = self.end_change.id

    return({
      'id':                   self.id,
      'area':                 self.area.id,
      'start_change':         start_change,
      'end_change':           end_change,
      'representative_point': self.representative_point.wkt,
      'geometry':             self.geometry.wkt
    })


  # ============================================================================
  class Meta:
    app_label = 'HistoGlobe_server'