"""
  This file contains the data model and their relations
  If this is changed, run
  $ python manage.py makemigrations
  $ python manage.py migrate
"""

# ==============================================================================
### INCLUDES ###

from django.contrib.gis.db import models
from djgeojson.fields import *
from django.utils import timezone
import rfc3339
import time




# ==============================================================================
### TEMPORAL DIMENSION ###
# (main organizational dimension)

# ------------------------------------------------------------------------------
## Hivent stores historical happenings at which the countries of Earth change

class Hivent(models.Model):
  name =            models.CharField          (max_length=150, default='')
  start_date =      models.DateTimeField      (null=True)
  end_date =        models.DateTimeField      (null=True)
  effect_date =     models.DateTimeField      (default=timezone.now)
  secession_date =  models.DateTimeField      (null=True)
  location_name =   models.CharField          (null=True, max_length=150)
  location_point =  models.PointField         (null=True)
  location_area =   models.MultiPolygonField  (null=True)
  description =     models.CharField          (null=True, max_length=1000)
  link_url =        models.CharField          (null=True, max_length=300)
  link_date =       models.DateTimeField      (null=True, default=timezone.now)


  def __unicode__(self):
    return self.name

  class Meta:
    ordering = ['-effect_date']  # descending order (2000 -> 0 -> -2000 -> ...)


# ==============================================================================
### SPATIAL / ATTRIBUTE DIMENSION ###

# ------------------------------------------------------------------------------
# Area stores geometry, representative point and name of an Area
# geometry:
#   TODO: currently MultiPolygon -> to be changes to more sophisticated model later
# representative point:
#   TODO: calculate reasonable name position with intelligent algorithm
# name:
#   common name,    e.g. 'Germany'
#   official name,  e.g. 'Federal Republic of Germany"
#   TODO: currently only English -> to be extended

class Area(models.Model):
  geom =                  models.MultiPolygonField  (default='MULTIPOLYGON EMPTY')
  representative_point =  models.PointField         (null=True)
  short_name =            models.CharField          (max_length=100, default='')
  formal_name =           models.CharField          (max_length=150, default='')
  sovereignty_status =    models.CharField          (null=True, max_length=1)
  territory_of =          models.ForeignKey         ('self', null=True, blank=True)
  start_hivent =          models.ForeignKey         (Hivent, related_name='start_hivent', null=True)
  end_hivent =            models.ForeignKey         (Hivent, related_name='end_hivent', null=True)

  # overriding the default manager with a GeoManager instance.
  # didn't quite understand what this is for...
  objects =               models.GeoManager         ()


  def __unicode__(self):
    return self.short_name


# ==============================================================================
# SNAPSHOTS (currently not used)
## Snapshot stores a complete image of all areas at a single moment in history
## --> needed for initialization of event-based spatio-temporal data model

class Snapshot(models.Model):
  date =        models.DateTimeField          (default=timezone.now)
  areas =       models.ManyToManyField        (Area)

  def __unicode__(self):
    return rfc3339.rfc3339(self.date)

  class Meta:
    ordering = ['-date']        # descending order (2000 -> 0 -> -2000 -> ...)




# ==============================================================================
### CONNECTION TABLES ###

# ------------------------------------------------------------------------------
# A change belongs to an Hivent and defines an explicit change of Areas
# -> see more in ChangeAreas
# Hivent 1:n Change

class Change(models.Model):
  hivent =      models.ForeignKey             (Hivent, related_name='hivent')
  operation =   models.CharField              (default='XXX', max_length=3)

  def __unicode__(self):
    return '%s: %s' % (self.hivent.id, self.operation)


# ------------------------------------------------------------------------------
## Change stores one explicit change of Areas of an Hivent
## (1 old Area -> 1 new Area)
## for specific historical geographic operations differently many changes can be
## assigned to one Area
##  ADD) add area:       - -> A
##  UNI) unification:    A1 -> B, A2 -> B, ... , An .-> B
##  SEP) separation:     A -> B1, A -> B2, ... , A -> Bn
##  CHB) border change:  A -> A', B -> B'
##  CHN) name change;    A -> A'
##  DEL) delete area:    A -> -
## e.g. 'CSSR' -> 'CZE' + 'SVK' => two changes for 'CSSR'

class ChangeAreas(models.Model):
  change =      models.ForeignKey             (Change, related_name='change')
  old_area =    models.ForeignKey             (Area, related_name='old_area', null=True)
  new_area =    models.ForeignKey             (Area, related_name='new_area', null=True)

  def __unicode__(self):
    return self.change.operation




# ------------------------------------------------------------------------------
# TODO: 'historical descendant' to create hierarchy of countries?
  # e.g. unified Germany if a descendant of West and East Germany
  # West Germany was a descendant of Nazi Germany, but East Germany formally was not -> "new country"