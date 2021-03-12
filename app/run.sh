#!/bin/bash

set -eo pipefail

# Check mode if it is 'SERVER' or 'CLIENT'
DSMR_MODE=${DSMR_MODE:-SERVER}
DSMR_MODE=`echo $DSMR_MODE | tr a-z A-Z`

if [ "$DSMR_MODE" != "SERVER" ] && [ "$DSMR_MODE" != "SERVER-NO-DATALOGGER" ] && [ "$DSMR_MODE" != "NO-DATALOGGER" ]; then
  echo "The 'DSMR_MODE' can only be 'SERVER', 'NO-DATALOGGER' or 'SERVER-NO-DATALOGGER'"
  sleep 1
  exit 1
fi

echo ""
date +"%F %T"
echo "Start DSMR Reader - Mode=$DSMR_MODE"

# Set right serial permissions
if [ -e '/dev/ttyUSB0' ]; then chmod 666 /dev/ttyUSB*; fi

# Remove pids, they can cause issue during a restart
rm -f /var/tmp/*.pid

# Check if we're able to connect to the database instance
# already. The port isn't required for postgresql.py but
# it is added for the sake of completion.
if [ -z "${DJANGO_DATABASE_PORT}" ]; then
  if [ -z "${DB_PORT}" ]; then
    DJANGO_DATABASE_PORT=5432
  else
    DJANGO_DATABASE_PORT=$DB_PORT
  fi
fi

if [ -z "${DJANGO_DATABASE_HOST}" ]; then DJANGO_DATABASE_HOST=$DB_HOST; fi
if [ -z "${DJANGO_DATABASE_USER}" ]; then DJANGO_DATABASE_USER=$DB_USER; fi
if [ -z "${DJANGO_DATABASE_NAME}" ]; then DJANGO_DATABASE_NAME=$DB_NAME; fi

cmd=$(command -v pg_isready)
cmd="$cmd -h $DJANGO_DATABASE_HOST -p $DJANGO_DATABASE_PORT -U $DJANGO_DATABASE_USER -d $DJANGO_DATABASE_NAME -t 1"

echo "Executing '$cmd'"

timeout=60
while ! $cmd >/dev/null 2>&1; do
  timeout=$(expr $timeout - 1)
  if [[ $timeout -eq 0 ]]; then
    echo "Could not connect to database server. Aborting..."
    return 1
  fi
  echo -n "."
  sleep 1
done

echo "Connected to database successfully"

# Run migrations
python3 manage.py migrate --noinput
python3 manage.py collectstatic --noinput

if [ -z "${DSMRREADER_ADMIN_USER}" ]; then DSMRREADER_ADMIN_USER=$DSMR_USER; fi
if [ -z "${DSMRREADER_ADMIN_PASSWORD}" ]; then DSMRREADER_ADMIN_PASSWORD=$DSMR_PASSWORD; fi

if [ -z "${DSMRREADER_ADMIN_USER}" ] || [ -z "${DSMRREADER_ADMIN_PASSWORD}" ]; then
  echo "DSMR web credentials not set. Exiting."
  exit 1
fi

# Create an admin user
python3 manage.py dsmr_superuser

if [ "$DSMR_MODE" == "SERVER" ]; then
  sed -i '/^\[program:dsmr_datalogger\]$/,/^\[/ s/^autostart=false/autostart=true/' /etc/supervisor.d/supervisord.ini
else
  sed -i '/^\[program:dsmr_datalogger\]$/,/^\[/ s/^autostart=true/autostart=false/' /etc/supervisor.d/supervisord.ini
fi

# Run supervisor
/usr/bin/supervisord -n

# End
