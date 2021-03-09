#!/usr/bin/env bash
set -o nounset
set -o pipefail
set -o xtrace

function crond() {

  CRONFILE="/crontab.conf"
  # Depending on deploment we will want to randomize the update time so all clamd nodes are not doing it at the same time
  CRON_M=$((1 + RANDOM % 58))
  CRON_H=$((1 + RANDOM % 4))
  if [[ -f "${CRONFILE}" ]]; then
    echo "OK: CRONFILE is present. Configuring crontab with settings in ${CRONFILE}..."
  else
    {
       echo 'SHELL=/bin/bash'
       echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
       echo '{{CRON_M}} {{CRON_H}} * * * /usr/bin/env bash -c 'freshclam --quiet' 2>&1'
    } | tee /crontab.conf
  fi

  sed -i 's|{{CRON_H}}|'"${CRON_H}"'|g' /crontab.conf
  sed -i 's|{{CRON_M}}|'"${CRON_M}"'|g' /crontab.conf

  # Load config
  cat ${CRONFILE} | crontab -
  crontab -l

  # Start crond
  runcrond="crond -b" && bash -c "${runcrond}"
}

function mode() {

  #PUBLICIPV4=$(route -n | awk '$2 ~/[1-9]+/ {print $2;}')
  #LOCALIPV4=$(route -n | awk '$2 ~/[1-9]+/ {print $2;}')
  LOCALIPV4=0.0.0.0
  PUBLICIPV4=0.0.0.0

  export PUBLICIPV4
  export LOCALIPV4

  echo "PUBLICIPV4=${PUBLICIPV4}" >> /network
  echo "LOCALIPV4=${LOCALIPV4}" >> /network

  # Set local IP
  sed -i 's|{{LOCALIPV4}}|'"${LOCALIPV4}"'|g' /etc/clamd.conf
  sed -i 's|{{PUBLICIPV4}}|'"${PUBLICIPV4}"'|g' /etc/clamd.conf

}

function freshclam() {

  # Update files if they are missing or older that X days
  chown -R clamav:clamav /var/lib/clamav/

  if [[ $(find "/var/lib/clamav/daily.cvd" -mtime +2 -print) ]] || [[ ! -f "/var/lib/clamav/daily.cvd" ]]; then
    echo "Clamd files are too old. Updating..."
    echo "OK: Running freshclam to update virus databases. This can take a few minutes..."
    sleep 1
    run="freshclam -d -c 12 -p /run/freshclam.pid" && bash -c "${run}"
  else
    echo "File clamd files are current"
  fi

}

function monit() {

  # Start Monit with delay to allow clam to startup and avoid race condition where monit attempts to start it prior to the command being passed
  {
    echo 'set daemon 15'
    echo '   with START DELAY 30'
    echo 'set pidfile /var/run/monit.pid'
    echo 'set statefile /var/run/monit.state'
    echo 'set httpd port 2849 and'
    echo '   use address localhost'
    echo '   allow localhost'
    echo 'set logfile syslog'
    echo 'set eventqueue'
    echo '   basedir /var/run'
    echo '   slots 100'
    echo 'include /etc/monit.d/*'
  } | tee /etc/monitrc

  find /etc/monit.d -maxdepth 5 -type f -exec sed -i -e 's|{{LOCALIPV4}}|'"${LOCALIPV4}"'|g' {} \;
  find /etc/monit.d -maxdepth 5 -type f -exec sed -i -e 's|{{PUBLICIPV4}}|'"${PUBLICIPV4}"'|g' {} \;

  chmod 700 /etc/monitrc
  run="monit -c /etc/monitrc" && bash -c "${run}"

}

function run() {
  mode
  freshclam
  crond
  monit

  echo "OK: All processes have completed. Service is ready..."
}

run

exec "$@"
