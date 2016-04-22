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

countries_full =    'ne_10m_admin_0_countries.geojson'   # source: Natural Earth Data
countries_reduced = 'ne_50m_admin_0_countries.geojson'   # source: Natural Earth Data

init_data_version_date = '2014-10-10'


# ------------------------------------------------------------------------------
def get_file(file_id):
  return os.path.abspath(os.path.join(
      os.path.dirname(HistoGlobe_server.__file__),
      'data/init_area_data/',
      file_id
    )
  )

# ------------------------------------------------------------------------------
def get_init_countries_file():
  return os.path.abspath(os.path.join(
      os.path.dirname(HistoGlobe_server.__file__),
      'data/init_source_areas',
      countries_reduced
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

  ### CLEANUP ###

  Hivent.objects.all().delete()
  Area.objects.all().delete()
  print('All objects deleted from database')


  ### INIT AREAS ###


  ## load initial areas from shapefile
  # distribute into the three tables

  json_data_string = open(get_init_countries_file())
  json_data = json.load(json_data_string)

  for feature in json_data['features']:
    short_name = feature['properties']['name_long']
    formal_name = feature['properties']['formal_en']
    if formal_name is None: formal_name = short_name
    geometry = GEOSGeometry(json.dumps(feature['geometry']))

    area = Area()
    area.save()

    area_territory = AreaTerritory(
        area =      area,
        geometry =  geometry
      )
    area_territory.save()

    area_name = AreaName(
        area =        area,
        short_name =  short_name,
        formal_name = formal_name
      )
    area_name.save()

    print("Area " + short_name + " created")



  ## update properties of initial areas
  ## and create creation hivent for this area

  with open(get_file('areas_to_update.csv'), 'r') as in_file:
    reader = csv.DictReader(in_file, delimiter='|', quotechar='"')
    for row in reader:

      # get area objects
      area_name = AreaName.objects.get(short_name=row['init_source_name'])
      area = area_name.area
      area_territory = AreaTerritory.objects.get(area=area)

      # update area
      area_name.short_name =    row['short_name'].decode('utf-8')
      area_name.formal_name =   row['formal_name'].decode('utf-8')
      area_name.save()

      print("Area " + str(area.id) + ': ' + area_name.short_name + " updated")

      # create hivent + change (add new country)
      creation_date = iso8601.parse_date(row['creation_date'])
      hivent = Hivent(
          name =        str(row['hivent_name']),
          start_date =  creation_date,
          effect_date = creation_date
        )
      hivent.save()

      historical_change = HistoricalChange(
          hivent =              hivent,
          operation =           'CRE'
        )
      historical_change.save()

      area_change = AreaChange(
          historical_change =   historical_change,
          operation =           'ADD',
          area =                area,
          new_area_name =       area_name,
          new_area_territory =  area_territory
        )
      area_change.save()

      area.start_change = area_change
      area.save()

      area_name.start_change = area_change
      area_name.save()

      area_territory.start_change = area_change
      area_territory.save()

      # area is still active, therefore it has no end_change

      print("Hivent " + hivent.name + " saved")


  ## delete areas

  with open(get_file('areas_to_delete.csv'), 'r') as in_file:
    reader = csv.DictReader(in_file, delimiter='|', quotechar='"')
    for row in reader:
      area_name = AreaName.objects.get(short_name=row['init_source_name'])
      area = area_name.area
      area.delete()

      print("Area " + area_name.short_name + " deleted")


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
          # get area
          old_area_name = AreaName.objects.get(short_name=row['old_area'])
          old_area = old_area_name.area
          old_area_territory = AreaTerritory.objects.get(area=old_area)

          # clip old and new geom
          B = new_geom
          A = old_area_territory.geometry
          old_geom = A.difference(B)
          new_geom = A.intersection(B)

          # assign old geometry to old area
          # geometry need to be MultiPolygon to fit to model
          if old_geom.geom_type != 'MultiPolygon':
            old_geom = MultiPolygon(old_geom)
          old_area_territory.geometry = old_geom

          old_area_territory.save()
          old_area.save()

          print(row['short_name'] + " separated from " + old_area_name.short_name)


        # geometry need to be MultiPolygon to fit to model
        if new_geom.geom_type != 'MultiPolygon':
          new_geom = MultiPolygon(new_geom)

        new_area = Area ()
        new_area.save()

        new_area_territory = AreaTerritory (
            area =          new_area,
            geometry =      new_geom
          )
        new_area_territory.save()

        new_area_name = AreaName (
            area =          new_area,
            short_name =    row['short_name'].decode('utf-8'),
            formal_name =   row['formal_name'].decode('utf-8'),
          )
        new_area_name.save()

        # create hivent + change (add new country)
        creation_date = iso8601.parse_date(row['creation_date'])
        hivent = Hivent(
            name =        str(row['hivent_name']),
            start_date =  creation_date,
            effect_date = creation_date
          )
        hivent.save()

        historical_change = HistoricalChange(
            hivent =              hivent,
            operation =           'CRE'
          )
        historical_change.save()

        area_change = AreaChange(
            historical_change =   historical_change,
            operation =           'ADD',
            area =                new_area,
            new_area_name =       new_area_name,
            new_area_territory =  new_area_territory
          )
        area_change.save()

        new_area.start_change = area_change
        new_area.save()

        new_area_name.start_change = area_change
        new_area_name.save()

        new_area_territory.start_change = area_change
        new_area_territory.save()

        print("Area for " + new_area_name.short_name + " with start hivent " + hivent.name + " created")


  ## merge areas that are parts of each other, mark territories

  with open(get_file('areas_to_merge.csv'), 'r') as in_file:
    reader = csv.DictReader(in_file, delimiter='|', quotechar='"')
    for row in reader:

      # unify if part of another country
      if (row['part_of'] != ''):

        # get areas
        home_area_name = AreaName.objects.get(short_name=row['part_of'])
        home_area = home_area_name.area
        home_area_territory = AreaTerritory.objects.get(area=home_area)

        part_area_name = AreaName.objects.get(short_name=row['init_source_name'])
        part_area = part_area_name.area
        part_area_territory = AreaTerritory.objects.get(area=part_area)

        # update geometry
        union_geom = home_area_territory.geometry.union(part_area_territory.geometry)
        if union_geom.geom_type != 'MultiPolygon':
          union_geom = MultiPolygon(union_geom)

        # update / delete areas
        home_area_territory.geometry = union_geom
        home_area_territory.save()
        part_area.delete()
        print(part_area_name.short_name + " was incorporated into " + home_area_name.short_name)


      # subordinate if territory of another country
      elif (row['territory_of'] != ''):

        # get areas
        home_area_name = AreaName.objects.get(short_name=row['territory_of'])
        home_area = home_area_name.area
        home_area_territory = AreaTerritory.objects.get(area=home_area)

        terr_area_name = AreaName.objects.get(short_name=row['init_source_name'])
        terr_area = terr_area_name.area
        terr_area_territory = AreaTerritory.objects.get(area=terr_area)

        # update areas
        terr_area_name.short_name =   row['short_name'].decode('utf-8')    # encoding problem :/
        terr_area_name.formal_name =  row['formal_name'].decode('utf-8')   # encoding problem :/
        terr_area_name.save()


        # add its area to the creation event
        historical_change = AreaChange.objects.get(area=home_area).historical_change

        area_change = AreaChange(
            historical_change =   historical_change,
            operation =           'ADD',
            area =                terr_area,
            new_area_name =       terr_area_name,
            new_area_territory =  terr_area_territory
          )
        area_change.save()

        terr_area.start_change = area_change
        terr_area.save()

        terr_area_name.start_change = area_change
        terr_area_name.save()

        terr_area_territory.start_change = area_change
        terr_area_territory.save()

        print(terr_area_name.short_name + " added to creation hivent of " + home_area_name.short_name)


  ### CREATE REPRESENTATIVE POINTS ###

  for area_territory in AreaTerritory.objects.all():
    area_territory.representative_point = area_territory.geometry.point_on_surface
    area_territory.save()
  print("representative point calculated for all areas")

  # print("Snapshot created for date: " + snapshot.date.strftime('%Y-%m-%d'))
