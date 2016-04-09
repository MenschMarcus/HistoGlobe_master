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
## (main organizational dimension)

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


# ------------------------------------------------------------------------------
## A change belongs to an Hivent and defines an explicit change of Areas
## Hivent 1:n Change
## operations:
#   ADD) add new area:      0 -> A
#   UNI) unification:       A, B -> C
#   INC) incorporation:     A, B -> A
#   SEP) separation:        A -> B, C
#   SEC) secession:         A -> A, B
#   NCH) name change:       A -> A
#   ICH) identity change:   A -> B
#   DEL) delete area:       A -> 0

class Change(models.Model):
  hivent =      models.ForeignKey ('Hivent', related_name='hivent')
  operation =   models.CharField  (default='XXX', max_length=3)

  def __unicode__(self):
    return '%s -> %s' % (self.hivent.name, self.operation)


# ------------------------------------------------------------------------------
## ChangeAreas stores one explicit change of Areas (id!)
## (0/1 old Area -> 0/1 new Area)
## Change 1:n ChangeAreas
## operations:
#   ADD) add new area:      0 -> A
#   UNI) unification:       A -> C, B -> C
#   INC) incorporation:     B -> A
#   SEP) separation:        A -> B, A -> C
#   SEC) secession:         A -> B
#   NCH) name change:
#   ICH) identity change:   A -> B
#   DEL) delete area:       A -> 0
# TODO: 'historical descendant' to create hierarchy of countries?
#   e.g. unified Germany if a descendant of West and East Germany
#   West Germany was a descendant of Nazi Germany, but East Germany formally was not -> "new country"

class ChangeAreas(models.Model):
  change =              models.ForeignKey ('Change', related_name='change')
  old_area =            models.ForeignKey ('Area',   related_name='old_area', null=True)
  new_area =            models.ForeignKey ('Area',   related_name='new_area', null=True)

  def __unicode__(self):
    return '%s: %s -> %s' % (self.change.operation, self.old_area.id, self.new_area.id )


# ------------------------------------------------------------------------------
## ChangeAreaNames stores one explicit change of Area names (no id change)
## (0/1 old AreaName -> 0/1 new AreaName)
## Change 1:n ChangeAreaNames
## operations:
#   ADD) add new area:      0 -> A
#   UNI) unification:       A -> 0, B -> 0, 0 -> C
#   INC) incorporation:     B -> 0
#   SEP) separation:        A -> 0, 0 -> B, 0 -> C
#   SEC) secession:         0 -> B
#   NCH) name change:       A -> A'
#   ICH) identity change:   A -> 0, 0 -> B
#   DEL) delete area:       A -> 0

class ChangeAreaNames(models.Model):
  change =              models.ForeignKey ('Change',   related_name='change')
  old_area_name =       models.ForeignKey ('AreaName', related_name='old_area_name', null=True)
  new_area_name =       models.ForeignKey ('AreaName', related_name='new_area_name', null=True)

  def __unicode__(self):
    return '%s: %s -> %s' % (self.change.operation, self.old_area_name.short_name, self.new_area_name.short_name )


# ------------------------------------------------------------------------------
## ChangeAreaTerritories stores one explicit change of Area names (no id change)
## (0/1 old AreaTerritory -> 0/1 new AreaTerritory)
## Change 1:n ChangeAreaTerritories
## operations:
#   ADD) add new area:      0 -> A
#   UNI) unification:       A -> 0, B -> 0, 0 -> C
#   INC) incorporation:     B -> 0, A -> A'
#   SEP) separation:        A -> 0, 0 -> B, 0 -> C
#   SEC) secession:         0 -> B, A -> A'
#   NCH) name change:
#   ICH) identity change:
#   DEL) delete area:       A -> 0

class ChangeAreaTerritories(models.Model):
  change =              models.ForeignKey ('Change',        related_name='change')
  old_area_territory =  models.ForeignKey ('AreaTerritory', related_name='old_area_territory', null=True)
  new_area_territory =  models.ForeignKey ('AreaTerritory', related_name='new_area_territory', null=True)

  def __unicode__(self):
    return '%s: %s -> %s' % (self.change.operation, self.old_area_territory.area.id, self.new_area_territory.area.id )


# ==============================================================================
### IDENTITY + SPATIAL + ATTRIBUTE DIMENSION ###

# ------------------------------------------------------------------------------
# Area is the identity dimension of an Area: An integral area, that might change
# its territory or its common name, but not its formal name
# new Area <=> new formal name
# ChangeArea.old_area 1:1 Area, ChangeArea.new_area 1:1 Area
# access predecessors and successors via start_/end_change

class Area(models.Model):
  start_change =          models.ForeignKey         ('Change', related_name='start_change')
  end_change =            models.ForeignKey         ('Change', related_name='start_change', null=True, blank=True)
  territories =           models.ForeignKey         ('self', null=True, blank=True)
  territory_of =          models.ForeignKey         ('self', null=True, blank=True)

  def __unicode__(self):
    return self.id


# ------------------------------------------------------------------------------
# AreaTerritory stores the spatial dimension of an Area
#   geometry
#   representative point:
#     TODO: calculate reasonable name position with intelligent algorithm

class AreaTerritory(models.Model):
  area =                  models.ForeignKey         ('Area', related_name='area')
  start_change =          models.ForeignKey         ('Change', related_name='start_change')
  end_change =            models.ForeignKey         ('Change', related_name='start_change', null=True, blank=True)
  geometry =              models.MultiPolygonField  (default='MULTIPOLYGON EMPTY')
  representative_point =  models.PointField         (null=True)

  # overriding the default manager with a GeoManager instance.
  # didn't quite understand what this is for...
  objects =               models.GeoManager         ()

  def __unicode__(self):
    return self.short_name


# ------------------------------------------------------------------------------
# AreaName stores the attribute dimension (name) of an area
#   short name,    e.g. 'Germany'
#   formal name,   e.g. 'Federal Republic of Germany"
#   TODO: currently only English -> to be extended

class AreaName(models.Model):
  area =                  models.ForeignKey         ('Area', related_name='area')
  start_change =          models.ForeignKey         ('Change', related_name='start_change')
  end_change =            models.ForeignKey         ('Change', related_name='start_change', null=True, blank=True)
  short_name =            models.CharField          (max_length=100, default='')
  formal_name =           models.CharField          (max_length=150, default='')

  def __unicode__(self):
    return self.area.id


# ------------------------------------------------------------------------------
# TerritoryRelation stores relations between a homeland (e.g. France) and its
# (overseas) territory with a certain status (e.g. 'colony' or 'free association')

class TerritoryRelation(models.Model):
  home_area =             models.ForeignKey         ('Area', related_name='home_area')
  dependency =            models.ForeignKey         ('Area', related_name='dependency')
  # type =                models.CharField          (max_lengthh=20, default='territory')