from django.contrib.gis.db import models
from djgeojson.fields import *

class WorldBorder(models.Model):
    # Regular Django fields corresponding to the attributes in the
    # world borders shapefile.
    name      = models.CharField(max_length=50)
    area      = models.IntegerField(null=True)
    pop2005   = models.IntegerField('Population 2005', null=True)
    fips      = models.CharField('FIPS Code', max_length=2, null=True)
    iso2      = models.CharField('2 Digit ISO', max_length=2, null=True)
    iso3      = models.CharField('3 Digit ISO', max_length=3, null=True)
    un        = models.IntegerField('United Nations Code', null=True)
    region    = models.IntegerField('Region Code', null=True)
    subregion = models.IntegerField('Sub-Region Code', null=True)
    lng       = models.FloatField(null=True)
    lat       = models.FloatField(null=True)

    # GeoDjango-specific: a geometry field (MultiPolygonField), and
    # overriding the default manager with a GeoManager instance.
    geom      = models.MultiPolygonField()
    objects   = models.GeoManager()

    # Returns the string representation of the model.
    def __unicode__(self):              # __unicode__ on Python 2
        return self.name


# ============================================================================ #
# =============== S H O P H I S T I C A T E D   M O D E L ==================== #
# ============================================================================ #

'''
# DIMENSION OF TIME (main organizational dimension)
# Hivent stores historical happenings at which the countries of Earth change

class Hivent(models.Model):
  name =        models.CharField(max_length=150)
  date =        models.DateField(default=date.today)
  location =    models.PointField(null=True)
  description = models.CharField(max_length=1000)

  def __unicode__(self):
    return self.name

# DIMENSION OF SPACE
# Shape stores only the geometry of a Unit
# TODO: currently MultiPolygon -> to be changes to more sophisticated model later

class Shape(models.Model):
  geom =        models.MultiPolygonField()
  objects =     models.GeoManager()         # didn't quite understand what this is for...


  def __unicode__(self):
    return self.geom


# DIMENSION OF ATTRIBUTE
# Name stores names of a Unit in different languages
# off = official name, e.g. 'Federal Republic of Germany"
# com = common name, e.g. 'Germany'
# additionally stores position of name

class Name(models.Model):
  pos =         models.PointField(null=True)
  en_off =      models.CharField(max_length=100)
  en_com =      models.CharField(max_length=50)

  def __unicode__(self):
    return self.en_comm

# TODO: currently only English -> to be extended
# TODO: calculate reasonable name position with intelligent algorithm


# ------------------------------------------------------------------------------
# HELPER CLASSES / ENTITIES
# ------------------------------------------------------------------------------


# AdminUnit combines dimensions of space (shape) and attribute (space) per unit

class AdminUnit(models.Model):
  name =        models.ForeignKey(Name)
  shape =       models.ForeignKey(Shape)

  def __unicode__(self):
    return self.name


# Change stores one explicit change of Units of an Hivent (1 old Unit -> 1 new Unit)
# for unifications, splitups, and border changes several changes can be assigned to one unit
  # e.g. 'CSSR' -> 'CZE' + 'SVK' => two changes for 'CSSR'

class Change(models.Model):
  hivent =      models.ForeignKey(Hivent)
  old_unit =    models.ForeignKey(AdminUnit, related_name='old_unit')
  new_unit =    models.ForeignKey(AdminUnit, related_name='new_unit')

  def __unicode__(self):
    return '%s: %s -> %s' % (self.hivent, self.old, self.new)

# TODO: 'historical descendant' to create hierarchy of countries?
  # e.g. unified Germany if a descendant of West and East Germany
  # West Germany was a descendant of Nazi Germany, but East Germany formally was not -> "new country"
'''
