# master_HistoGlobe
the backend editor version of HistoGlobe

NAME SCHEME & VARIABLES
-----------------------

root:           HistoGlobe
db name:        histoglobe_database
db user:        HistoGlobe_user
db passw:       12345
db superuser:   HistoGlobe_superuser
db su E-Mail:   marcus.kossatz@histoglobe.com
db su pw:       123456789
django project: HistoGlobe_admin_project
django app:     HistoGlobe_server
django static:  HistoGlobe_client


NORMAL ACCESS TO DB
-------------------
sudo -i -u postgres
psql
\c histoglobe_database
un: postgres
pw: postgres

CREATE DATABASE
---------------

sudo -i -u postgres
createdb histoglobe_database -O HistoGlobe_user
psql histoglobe_database -c "GRANT ALL ON ALL TABLES IN SCHEMA public to HistoGlobe_user;"
psql histoglobe_database -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA public to HistoGlobe_user;"
psql histoglobe_database -c "GRANT ALL ON ALL FUNCTIONS IN SCHEMA public to HistoGlobe_user;"
psql histoglobe_database -c "GRANT ALL PRIVILEGES ON DATABASE histoglobe_database TO HistoGlobe_user;"
psql histoglobe_database -c "CREATE EXTENSION postgis;"


================================================================================

INSTALLATION MANUAL
-------------------

## install python, postgresql, postgis and its components
sudo apt-get install python3 python-pip python-dev libpq-dev postgresql postgresql-contrib postgresql-server-dev-9.3 libxml2-dev postgresql-9.3-postgis-2.1

## setup postgres database and user
sudo su - postgres
psql
CREATE DATABASE histoglobe_database;
CREATE USER HistoGlobe_user WITH PASSWORD '12345';
ALTER ROLE HistoGlobe_user SET client_encoding TO 'utf8';
ALTER ROLE HistoGlobe_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE HistoGlobe_user SET timezone TO 'UTC';

# 2x 'ctrl+d' to leave psql and get back to normal user

## postgis, GeoDjango and postgres management gui
sudo apt-get install postgresql-client pgadmin3 postgis gdal-bin python-gdal libgeoip1
sudo pip install dj-database-url django-leaflet django-geojson

## setup postgis
sudo -i -u postgres
psql
\c histoglobe_database
CREATE EXTENSION postgis;
-- Enable Topology
CREATE EXTENSION postgis_topology;
-- fuzzy matching needed for Tiger
CREATE EXTENSION fuzzystrmatch;
-- Enable US Tiger Geocoder
CREATE EXTENSION postgis_tiger_geocoder;

## setup GEOS
mkdir ~/.geos
cd ~/.geos
wget http://download.osgeo.org/geos/geos-3.5.0.tar.bz2
tar xjf geos-3.5.0.tar.bz2
cd geos-3.5.0
./configure --with-python
make
sudo make install
cd ..
rm geos-3.5.0.tar.bz2

## setup PROJ4.0
mkdir ~/.proj4
cd ~/.proj4
wget http://download.osgeo.org/proj/proj-4.8.0.tar.gz
wget http://download.osgeo.org/proj/proj-datumgrid-1.5.tar.gz
tar xzf proj-4.8.0.tar.gz
cd proj-4.8.0/nad
tar xzf ../../proj-datumgrid-1.5.tar.gz
cd ..
./configure
make
sudo make install
rm proj-4.8.0.tar.gz proj-datumgrid-1.5.tar.gz

## setup GDL
sudo apt-get install build-essential python-all-dev
mkdir ~/.gdal
cd ~/.gdal
wget http://download.osgeo.org/gdal/1.11.0/gdal-1.11.0.tar.gz
tar xvfz gdal-1.11.0.tar.gz
cd gdal-1.11.0
./configure --with-python
make
sudo make install
cd ..
rm gdal-1.11.0.tar.gz


## install django in virtual environment (in home folder)
sudo pip install virtualenv
cd ~
virtualenv .python_ve
source .python_ve/bin/activate
sudo pip install Django==1.9.4
sudo pip install psycopg2 --upgrade

## start django project
cd ~/HistoGlobe/master/HistoGlobe
django-admin.py startproject hg .
python manage.py startapp HistoGlobe_client

## set up project and
subl hg/settings.py

#replace the DATABASES part with following lines
--------------------------------------------------------------------------------
...
DATABASES = {
    'default': {
        'ENGINE':   'django.contrib.gis.db.backends.postgis',
        'NAME':     'histoglobe_database',
        'USER':     'HistoGlobe_user',
        'PASSWORD': '12345',
        'HOST':     'localhost',
        'PORT':     '',
    }
}
...
INSTALLED_APPS = (
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.gis',
    'HistoGlobe_server'
)
...
--------------------------------------------------------------------------------

## migrate database
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser

## setup superuser
python manage.py createsuperuser
HistoGlobe_superuser
marcus.kossatz@histoglobe.com
123456789

## activate server
python manage.py runserver 0.0.0.0:8000

## test site in web browser:
http://localhost:8000/
http://localhost:8000/api
  un: hg_superusr
  pw: hg_superpw


test database
-------------

-- Create table with spatial column
CREATE TABLE hg.test (
  id    SERIAL PRIMARY KEY,
  geom  GEOMETRY(Point, 26910),
  name  VARCHAR(128)
);

-- Add a spatial index
CREATE INDEX test_gix
  ON hg.test
  USING GIST (geom);

-- Add a point
INSERT INTO hg.test (geom) VALUES (
  ST_GeomFromText('POINT(0 0)', 26910)
);

-- Query point
SELECT *
FROM hg.test;


using pgadmin
-------------

just open pgAdmin III

ServerGroups
  -> Servers
    -> hgis
      -> Databases
        -> histoglobe_database
          -> Schemas
            -> pubilc
              -> Tables
                -> HistoGlobe_xxx


importing shp
-------------

shp2psql in_file.shp > out_file.sql


use django
----------
$ django-admin.py startproject hgis
