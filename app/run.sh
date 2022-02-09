#!/bin/bash

set -eo pipefail

function LOG()
{
  dt=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$dt $@"
}

function CheckDBConnection()
{
  CMD=$(command -v pg_isready)
  CMD="$CMD -h $DJANGO_DATABASE_HOST -p $DJANGO_DATABASE_PORT -U $DJANGO_DATABASE_USER -d $DJANGO_DATABASE_NAME -t 1"

  LOG "INFO: Executing '$CMD'"

  timeout=60
  while ! $CMD >/dev/null 2>&1; do
    timeout=$(expr $timeout - 1)
    if [[ $timeout -eq 0 ]]; then
      LOG "ERROR: Could not connect to database server. Aborting..."
      return 1
    fi
    echo -n "."
    sleep 1
  done

  LOG "INFO: Connected to database successfully"
}

# Uppercase mode
DSMR_MODE=${DSMR_MODE^^}

if [ "$DSMR_MODE" == "SERVER" ]; then
  DSMR_MODE=SERVER
elif [ "$DSMR_MODE" == "CLIENT" ] || [ "$DSMR_MODE" == "DATALOGGER" ]; then
  DSMR_MODE=DATALOGGER
elif [ "$DSMR_MODE" == "SERVER-NO-DATALOGGER" ] || [ "$DSMR_MODE" == "NO-DATALOGGER" ]; then
  DSMR_MODE=SERVER-NO-DATALOGGER
else
  LOG "ERROR: Invalid DSMR_MODE, only SERVER, DATALOGGER or SERVER-NO-DATALOGGER allowed"
  sleep 60
  exit 1
fi 

# We only support:
#  - SERVER
#  - SERVER-NO-DATALOGGER
#  - DATALOGGER

LOG "" 
LOG "INFO: Start DSMR Reader - Mode=$DSMR_MODE"

# Set right serial permissions
if [ -e '/dev/ttyUSB0' ]; then chmod 666 /dev/ttyUSB*; fi

# Remove pids, they can cause issue during a restart
rm -f /var/tmp/*.pid

# Check old environment values
if [ ! -z "${DB_PORT}" ]; then DJANGO_DATABASE_PORT=$DB_PORT; fi
if [ ! -z "${DB_HOST}" ]; then DJANGO_DATABASE_HOST=$DB_HOST; fi
if [ ! -z "${DB_USER}" ]; then DJANGO_DATABASE_USER=$DB_USER; fi
if [ ! -z "${DB_NAME}" ]; then DJANGO_DATABASE_NAME=$DB_NAME; fi
if [ ! -z "${DSMR_USER}" ]; then DSMRREADER_ADMIN_USER=$DSMR_USER; fi
if [ ! -z "$DSMR_PASSWORD" ]; then DSMRREADER_ADMIN_PASSWORD=$DSMR_PASSWORD; fi

if [ "$DSMR_MODE" == "SERVER" ] || [ "$DSMR_MODE" == "SERVER-NO-DATALOGGER" ]; then

  # DB needs to up-and-running
  CheckDBConnection

  # Run migrations
  python3 manage.py migrate --noinput
  python3 manage.py collectstatic --noinput

  # Create an admin user
  python3 manage.py dsmr_superuser
fi

if [ "$DSMR_MODE" == "SERVER" ]; then
  sed -i '/^\[program:dsmr_datalogger\]$/,/^\[/ s/^autostart=.*/autostart=true/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:dsmr_backend\]$/,/^\[/ s/^autostart=.*/autostart=true/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:dsmr_webinterface\]$/,/^\[/ s/^autostart=.*/autostart=true/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:nginx\]$/,/^\[/ s/^autostart=.*/autostart=true/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:dsmr_client_datalogger\]$/,/^\[/ s/^autostart=.*/autostart=false/' /etc/supervisor.d/supervisord.ini
elif [ "$DSMR_MODE" == "DATALOGGER" ]; then
  sed -i '/^\[program:dsmr_datalogger\]$/,/^\[/ s/^autostart=.*/autostart=false/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:dsmr_backend\]$/,/^\[/ s/^autostart=.*/autostart=false/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:dsmr_webinterface\]$/,/^\[/ s/^autostart=.*/autostart=false/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:nginx\]$/,/^\[/ s/^autostart=.*/autostart=false/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:dsmr_client_datalogger\]$/,/^\[/ s/^autostart=.*/autostart=true/' /etc/supervisor.d/supervisord.ini
else
  sed -i '/^\[program:dsmr_datalogger\]$/,/^\[/ s/^autostart=.*/autostart=false/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:dsmr_backend\]$/,/^\[/ s/^autostart=.*/autostart=true/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:dsmr_webinterface\]$/,/^\[/ s/^autostart=.*/autostart=true/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:nginx\]$/,/^\[/ s/^autostart=.*/autostart=true/' /etc/supervisor.d/supervisord.ini
  sed -i '/^\[program:dsmr_client_datalogger\]$/,/^\[/ s/^autostart=.*/autostart=false/' /etc/supervisor.d/supervisord.ini
fi

# Run supervisor
/usr/bin/supervisord -n

# End
