#!/usr/bin/env bash

set -o nounset
set -o pipefail
set -o xtrace


function crond() {

  if [[ -f "${CRONFILE}" ]]; then
    echo "OK: CRONFILE is present. Configuring crontab with settings in ${CRONFILE}..."
  else
    {
       echo 'SHELL=/bin/bash'
       echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
       echo '59 3 * * * /usr/bin/env bash -c 'freshclam --quiet' 2>&1'
    } | tee /crontab.conf
  fi

  # Load config
  cat ${CRONFILE} | crontab -
  crontab -l

  # Start crond
  runcrond="crond -b" && bash -c "${runcrond}"
}

function mode() {

  PUBLICIPV4=$(route -n | awk '$2 ~/[1-9]+/ {print $2;}')
  LOCALIPV4=$(route -n | awk '$2 ~/[1-9]+/ {print $2;}')

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
  if [[ $(find "/var/lib/clamav/daily.cvd" -mtime +2 -print) ]] || [[ ! -f "/var/lib/clamav/daily.cvd" ]]; then
    echo "Clamd files are missing or too old. Updating..."
    wget -t 5 -T 99999 -O /var/lib/clamav/main.cvd http://database.clamav.net/main.cvd
    wget -t 5 -T 99999 -O /var/lib/clamav/daily.cvd http://database.clamav.net/daily.cvd
    wget -t 5 -T 99999 -O /var/lib/clamav/bytecode.cvd http://database.clamav.net/bytecode.cvd
  else
    echo "File clamd files exists and current"
  fi

  chown clamav:clamav /var/lib/clamav/*.cvd

  echo "OK: Running freshclam to update virus databases. This can take a few minutes..."
  sleep 1
  run="freshclam -d -c 12 -p /var/run/freshclam.pid --quiet" && bash -c "${run}"

}

function monit() {

  # Start Monit
  {
    echo 'set daemon 10'
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
  find /etc/monit.d -maxdepth 5 -type f -exec sed -i -e 's|{{LOCALIPV4}}|'"${PUBLICIPV4}"'|g' {} \;

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
