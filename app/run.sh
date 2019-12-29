#!/bin/bash

set -eo pipefail
COMMAND="$@"

# Check mode if it is 'SERVER' or 'CLIENT'
DSMR_MODE=${DSMR_MODE:-SERVER}
DSMR_MODE=`echo $DSMR_MODE | tr a-z A-Z`

if [ "$DSMR_MODE" != "SERVER" ] && [ "$DSMR_MODE" != "CLIENT" ] && [ "$DSMR_MODE" != "SERVER-NO-DATALOGGER" ]; then
  echo "The 'DSMR_MODE' can only be 'SERVER', 'CLIENT' or 'SERVER-NO-DATALOGGER'"
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

# Check for throttle environment variables
if [ -n "${DSMR_BACKEND_SLEEP}" ]; then
  if grep 'DSMRREADER_BACKEND_SLEEP' /dsmr/dsmrreader/settings.py; then
    echo "Setting DSMRREADER_BACKEND_SLEEP already present, replacing values ..."
    sed -i "s/DSMRREADER_BACKEND_SLEEP=.*/DSMRREADER_BACKEND_SLEEP=${DSMR_BACKEND_SLEEP}/g" /dsmr/dsmrreader/settings.py
  else
    echo "Adding setting DSMRREADER_BACKEND_SLEEP ..."
    sed -i "/# Default settings/a DSMRREADER_BACKEND_SLEEP=${DSMR_BACKEND_SLEEP}" /dsmr/dsmrreader/settings.py
  fi
fi
if [ -n "${DSMR_DATALOGGER_SLEEP}" ]; then
  if grep 'DSMRREADER_DATALOGGER_SLEEP' /dsmr/dsmrreader/settings.py; then
    echo "Setting DSMRREADER_DATALOGGER_SLEEP already present, replacing values ..."
    sed -i "s/DSMRREADER_DATALOGGER_SLEEP=.*/DSMRREADER_DATALOGGER_SLEEP=${DSMR_DATALOGGER_SLEEP}/g" /dsmr/dsmrreader/settings.py
  else
    echo "Adding setting DSMRREADER_DATALOGGER_SLEEP ..."
    sed -i "/# Default settings/a DSMRREADER_DATALOGGER_SLEEP=${DSMR_DATALOGGER_SLEEP}" /dsmr/dsmrreader/settings.py
  fi
fi

# We can support (remote) client mode too
if [ "$DSMR_MODE" == "SERVER" ] || [ "$DSMR_MODE" == "SERVER-NO-DATALOGGER" ]; then
  # Check if we're able to connect to the database instance
  # already. The port isn't required for postgresql.py but
  # it is added for the sake of completion.
  DB_PORT=${DB_PORT:-5432}

  cmd=$(command -v pg_isready)
  cmd="$cmd -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t 1"

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

  # Override command if needed - this allows you to run
  # python3 manage.py for example. Keep in mind that the
  # WORKDIR is set to /dsmr.
  if [ -n "$COMMAND" ]; then
    echo "ENTRYPOINT: Executing override command"
    exec $COMMAND
  fi

  if [ -z "${DSMR_USER}" ] || [ -z "$DSMR_EMAIL" ] || [ -z "${DSMR_PASSWORD}" ]; then
    echo "DSMR web credentials not set. Exiting."
    exit 1
  fi

  # Create an admin user
  python3 manage.py shell -i python << PYTHON
from django.contrib.auth.models import User
if not User.objects.filter(username='${DSMR_USER}'):
  User.objects.create_superuser('${DSMR_USER}', '${DSMR_EMAIL}', '${DSMR_PASSWORD}')
  print('${DSMR_USER} created')
else:
  print('${DSMR_USER} already exists')
PYTHON

  if [ "$DSMR_MODE" == "SERVER" ]; then
    cp /etc/supervisor.d/supervisord.ini.server /etc/supervisor.d/supervisord.ini
  else
    cp /etc/supervisor.d/supervisord.ini.server-no-datalogger /etc/supervisor.d/supervisord.ini
  fi
else
  cp /etc/supervisor.d/supervisord.ini.client /etc/supervisor.d/supervisord.ini
fi

# Run supervisor
/usr/bin/supervisord -n

# End
