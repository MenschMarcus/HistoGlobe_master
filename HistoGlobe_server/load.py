"""
  This file does all the initialization work for the database:
  - create inital set of Areas of the world in in year 2015.
  - create initial snapshot for the year 2015
  - populate representative_point field in area table

  Caution: This can be performed ONLY in the beginning, when it is clear that
  all areas in the database are actually active in 2015. As soon as the first
  historical country is added, this script is not usable anymore.

  how to run:
  -----------

sudo su - postgres
psql
CREATE DATABASE histoglobe_database;
CREATE USER HistoGlobe_user WITH PASSWORD '12345';
ALTER ROLE HistoGlobe_user SET client_encoding TO 'utf8';
ALTER ROLE HistoGlobe_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE HistoGlobe_user SET timezone TO 'UTC';
\c histoglobe_database
CREATE EXTENSION postgis;
CREATE EXTENSION postgis_topology;
CREATE EXTENSION fuzzystrmatch;
CREATE EXTENSION postgis_tiger_geocoder;
\q
exit

## load model migrate
python manage.py makemigrations
python manage.py migrate

## prepare
python manage.py shell
from HistoGlobe_server import load
load.run()




"""


# ==============================================================================
### INCLUDES ###

# general python modules
import os
import csv
import json
import iso8601      # for date string -> date object

# GeoDjango
from django.contrib.gis.utils import LayerMapping
from django.contrib.gis.geos import *

# own
import HistoGlobe_server
from models import *



# ==============================================================================
### VARIABLES ###

area_mapping = {
  'geometry' :     'MULTIPOLYGON',
  'short_name' :   'name_long'
}

countries_full =    'ne_10m_admin_0_countries.shp'   # source: Natural Earth Data
countries_reduced = 'ne_50m_admin_0_countries.shp'   # source: Natural Earth Data

shapefile = os.path.abspath(os.path.join(
    os.path.dirname(HistoGlobe_server.__file__),
    'data/init_source_areas/',
    countries_reduced
  )
)

shapefile_version_date = '2014-10-10'


# ------------------------------------------------------------------------------
def get_file(file_id):
  return os.path.abspath(os.path.join(
      os.path.dirname(HistoGlobe_server.__file__),
      'data/init_area_data/',
      file_id
    )
  )


# ==============================================================================
### MAIN FUNCTION ###

def run(verbose=True):

  # automate this using:
  # psycopg2

  ### CREATE DATABASE ###
  """
## setup postgres database and user
sudo su - postgres
psql
CREATE DATABASE histoglobe_database;
CREATE USER HistoGlobe_user WITH PASSWORD '12345';
ALTER ROLE HistoGlobe_user SET client_encoding TO 'utf8';
ALTER ROLE HistoGlobe_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE HistoGlobe_user SET timezone TO 'UTC';
\c histoglobe_database
CREATE EXTENSION postgis;
CREATE EXTENSION postgis_topology;
CREATE EXTENSION fuzzystrmatch;
CREATE EXTENSION postgis_tiger_geocoder;
\q
exit

## load model migrate
python manage.py makemigrations
python manage.py migrate

## prepare
python manage.py shell
from HistoGlobe_server import load
load.run()

  """

  ### INIT AREAS ###

  ## load initial areas from shapefile

  areas = LayerMapping(
    Area,
    shapefile,
    area_mapping,
    transform=False,
    encoding='utf-8'
  )
  areas.save(strict=True, verbose=verbose)


  ## update properties of initial areas
  ## and create creation hivent for this area

  with open(get_file('current_areas.csv'), 'r') as in_file:
    reader = csv.DictReader(in_file, delimiter='|', quotechar='"')
    for row in reader:

      # update area
      area = Area.objects.get(short_name=row['init_source_name'])
      area.short_name =            row['short_name'].decode('utf-8')
      area.formal_name =           row['formal_name'].decode('utf-8')
      area.sovereignty_status =    row['sovereignty_status']
      area.save()
      print("Area " + str(area.id) + ': ' + area.short_name + " saved")

      # create hivent + change (add new country)
      creation_date = iso8601.parse_date(row['creation_date'])
      hivent = Hivent(
          name =        str(row['hivent_name']),
          start_date =  creation_date,
          effect_date = creation_date
        )
      hivent.save()
      change = Change(
          hivent =      hivent,
          operation =   'ADD'
        )
      change.save()
      change_areas = ChangeAreas(
          change =      change,
          old_area =    None,
          new_area =    area
        )
      change_areas.save()

      # double-link: set hivent as start hivent of area
      area.start_hivent = hivent
      # area is still active, therefore it has no end_hivent
      area.save()
      print("Hivent " + hivent.name + " saved")


  ## delete areas

  with open(get_file('areas_to_delete.csv'), 'r') as in_file:
    reader = csv.DictReader(in_file, delimiter='|', quotechar='"')
    for row in reader:
      area = Area.objects.get(short_name=row['init_source_name'])
      area.delete()
      print("Area " + area.short_name + " deleted")


  ## create new areas

  with open(get_file('areas_to_create.csv'), 'r') as in_file:
    reader = csv.DictReader(in_file, delimiter='|', quotechar='"')
    for row in reader:

      # get geometry from source file
      with open(get_file(row['source'])) as geom_source_file:
        new_geom_json = json.load(geom_source_file)
        new_geom_string = json.dumps(new_geom_json)
        new_geom = GEOSGeometry(new_geom_string)

        # separate from original country (clip)
        if row['operation'] == 'SEP':
          old_area = Area.objects.get(short_name=row['old_area'])
          # clip old and new geom
          B = new_geom
          A = old_area.geom
          old_geom = A.difference(B)
          new_geom = A.intersection(B)
          # assign old geometry to old area
          if old_geom.geom_type != 'MultiPolygon':
            old_geom = MultiPolygon(old_geom)
          old_area.geom = old_geom

          print(row['short_name'] + " separated from " + old_area.short_name)
          old_area.save()

        # prepare new geometry
        if new_geom.geom_type != 'MultiPolygon':
          new_geom = MultiPolygon(new_geom)

        new_area = Area (
            short_name =            row['short_name'].decode('utf-8'),
            formal_name =           row['formal_name'].decode('utf-8'),
            geom =                  new_geom,
            sovereignty_status =    row['sovereignty_status']
          )
        new_area.save()

        # create hivent + change (add new country)
        creation_date = iso8601.parse_date(row['creation_date'])
        hivent = Hivent(
            name =        str(row['hivent_name']),
            start_date =  creation_date,
            effect_date = creation_date
          )
        hivent.save()
        change = Change(
            hivent =      hivent,
            operation =   'ADD'
          )
        change.save()
        change_areas = ChangeAreas(
            change =      change,
            old_area =    None,
            new_area =    new_area
          )
        change_areas.save()

        # double-link: set hivent as start hivent of area
        new_area.start_hivent = hivent
        # area is still active, therefore it has no end_hivent
        new_area.save()


        print("Area for " + new_area.short_name + " with start hivent " + hivent.name + " created")
        new_area.save()



  # merge areas that are parts of each other, mark territories
  with open(get_file('areas_to_merge.csv'), 'r') as in_file:
    reader = csv.DictReader(in_file, delimiter='|', quotechar='"')
    for row in reader:

      # unify if part of another country
      if (row['part_of'] != ''):
        home_area = Area.objects.get(short_name=row['part_of'])
        part_area = Area.objects.get(short_name=row['init_source_name'])

        union_geom = home_area.geom.union(part_area.geom)
        if union_geom.geom_type != 'MultiPolygon':
          union_geom = MultiPolygon(union_geom)

        # update / delete areas
        home_area.geom = union_geom
        home_area.save()
        part_area.delete()
        print(part_area.short_name + " was incorporated into " + home_area.short_name)


      # subordinate if territory of another country
      elif (row['territory_of'] != ''):
        home_area = Area.objects.get(short_name=row['territory_of'])
        terr_area = Area.objects.get(short_name=row['init_source_name'])

        terr_area.short_name =   row['short_name'].decode('utf-8')    # encoding problem :/
        terr_area.formal_name =  row['formal_name'].decode('utf-8')   # encoding problem :/
        terr_area.territory_of = home_area
        terr_area.save()
        print(terr_area.short_name + " became territory of " + home_area.short_name)

        # add its area to creation event
        change = ChangeAreas.objects.get(new_area=home_area).change
        change_areas = ChangeAreas(
          change =      change,
          old_area =    None,
          new_area =    terr_area
        )
        change_areas.save()

        # double-link: set hivent as start hivent of area
        terr_area.start_hivent = change.hivent
        # area is still active, therefore it has no end_hivent
        terr_area.save()

        print(terr_area.short_name + " added to creation hivent of " + home_area.short_name)



  ### create representative point ###
  for area in Area.objects.all():
    area.representative_point = area.geom.point_on_surface
    area.save()
  print("representative point calculated for all areas")


  ### CREATE FIRST SNAPSHOT ###

  # save initial snapshot
  s1 = Snapshot(date=iso8601.parse_date(shapefile_version_date))
  s1.save()

  # populate snapshot with all areas in the database
  for area in Area.objects.all():
    s1.areas.add(area);

  print("Snapshot created for date: " + s1.date.strftime('%Y-%m-%d'))