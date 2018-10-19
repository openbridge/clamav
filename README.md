
# Docker ClamAV

We have paired Docker with ClamAV®. This delivers an easy to deploy open source (GPL) anti-virus engine used that can be used in variety of situations including email scanning, web scanning, and end point security.  

The service runs `clamd` within a lightweight Alpine Linux Docker image. This provides a portable, flexible and scalable multi-threaded daemon, a command line scanner, builds with the current virus databases and runs `freshclam` in the background.

# Usage
First, you can build the image or pull it:

### Get the image
```bash
docker build -t openbridge/clamav .
```
The easier thing to do would be to pull it:
```bash
docker pull openbridge/clamav
```
### Starting your container
Next, to run the image you can use:
```bash
docker run -d -p 3310:3310 openbridge/clamav
```
 or via a simpler (recommended!) approach is to use the included Docker compose file:
```bash
docker-compose up -d
```

The benefit of compose is the use of a Docker volume to hold the clam database files which allows them to persist across builds and updates.

```bash
volumes:
  clamd_data:
    driver: local
```

# Configuration

There are a few different configuration files. The principle is for `clamd` as it governs the core behavior of the service.


## Clamd

`clamd` is listening on exposed port 3310. We use a default configuration:

```bash
LogSyslog yes
PidFile /var/run/clamd.pid
LocalSocket /var/run/clamd.sock
FixStaleSocket true
LocalSocketGroup clamav
LocalSocketMode 666
TemporaryDirectory /tmp
DatabaseDirectory /var/lib/clamav
TCPSocket 3310
TCPAddr {{PUBLICIPV4}}
MaxConnectionQueueLength 200
MaxThreads 10
ReadTimeout 400
Foreground true
StreamMaxLength 100M
HeuristicScanPrecedence yes
StructuredDataDetection no
#StructuredSSNFormatNormal yes
ScanPE yes
ScanELF yes
DetectBrokenExecutables yes
ScanOLE2 yes
ScanPDF yes
ScanSWF yes
ScanMail yes
PhishingSignatures yes
PhishingScanURLs yes
ScanArchive yes
ArchiveBlockEncrypted no
MaxScanSize 1000M
MaxFileSize 1000M
Bytecode yes
BytecodeSecurity TrustSigned
BytecodeTimeout 240000
```
## Freshclam
freshclam is a virus database update tool for ClamAV. It is run as a background process via `cron`:

```bash
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
59 3 * * * /usr/bin/env bash -c 'freshclam --quiet' 2>&1
```

The default configuration for `freshclam`:
```bash
LogSyslog yes
DatabaseMirror database.clamav.net
TestDatabases yes
ReceiveTimeout 60
ConnectTimeout 60
```
Freshclam may be triggered by `/etc/monitrc` as well. See "Monitoring" below.

# Virus Tests
A virus test check will run periodically via `/bin/bash -c '/tests/test_virus.sh'`. This is run to validate that clamd is able to scan for known virus signatures. If this test fails, then the container will restart.

The following are the test virus signature files in `/tests/virus/`:

```bash
clam-v2.rar
lam-v3.rar
clam.cab
clam.exe
clam.exe.bz2
clam.zip
eicar.com
multi.zip
program.doc
test.rar
test.txt
Программа.doc
```

# Monitoring
Services in the container are monitored via `monit`. Monit is orchestrating the automated monitoring for various health and upkeep operations. For example, here are a few operations it cares for:

```bash
check process clamd-process with pidfile /run/clamav/clamd.pid
    start program = "/bin/bash -c '/usr/bin/clam start'" with timeout 60 seconds
    stop program = "/bin/bash -c '/usr/bin/clam stop'"
    if cpu > 90% for 8 cycles then restart
    if 5 restarts within 5 cycles then timeout

check program clamd-scan-check with path "/bin/bash -c '/tests/test_virus.sh'"
    every 10 cycles
    start program = "/bin/bash -c '/usr/bin/clam start'" with timeout 60 seconds
    stop program = "/bin/bash -c '/usr/bin/clam stop'"
    if status != 0 for 2 cycles then stop

check host clamd-server-port with address {{PUBLICIPV4}}
    start program = "/bin/bash -c '/usr/bin/clam start'" with timeout 60 seconds
    stop program = "/bin/bash -c '/usr/bin/clam stop'"
    if failed port 3310 for 3 cycles then restart

check file clamd-db-main with path /var/lib/clamav/main.cvd
    if timestamp > 80 hour then exec "/usr/bin/freshclam --quiet"

check file clamd-db-daily with path /var/lib/clamav/daily.cvd
    if timestamp > 80 hour then exec "/usr/bin/freshclam --quiet"

check file clamd-db-bytecode with path /var/lib/clamav/bytecode.cvd
    if timestamp > 80 hour then exec "/usr/bin/freshclam --quiet"
```

### Verify Status
To verify that everything is running as expected in the container you can use Monit status. The command will look something like this: `docker exec -it clamd monit status`. This will generate the Monit status view:

```bash
Monit 5.25.1 uptime: 0m

Process 'cron'
  status                       OK
  monitoring status            Monitored
  monitoring mode              active
  on reboot                    start
  pid                          22
  parent pid                   1
  uid                          0
  effective uid                0
  gid                          0
  uptime                       0m
  threads                      1
  children                     0
  cpu                          0.0%
  cpu total                    0.0%
  memory                       0.0% [40 kB]
  memory total                 0.0% [40 kB]
  security attribute           (null)
  disk write                   0 B/s [4 kB total]
  data collected               Fri, 19 Oct 2018 15:59:44

Process 'clamd-process'
  status                       OK
  monitoring status            Monitored
  monitoring mode              active
  on reboot                    start
  pid                          1
  parent pid                   0
  uid                          0
  effective uid                0
  gid                          0
  uptime                       0m
  threads                      3
  children                     3
  cpu                          0.0%
  cpu total                    0.0%
  memory                       6.8% [543.3 MB]
  memory total                 6.8% [543.8 MB]
  security attribute           (null)
  disk read                    0 B/s [60 kB total]
  disk write                   0 B/s [524 kB total]
  data collected               Fri, 19 Oct 2018 15:59:44

Program 'clamd-scan-check'
  status                       OK
  monitoring status            Waiting
  monitoring mode              active
  on reboot                    start
  last exit value              0
  last output                  + set -o nounset
                               + set -o pipefail
                               + source /network
                               ++ PUBLICIPV4=172.26.0.1
                               ++ LOCALIPV4=172.26.0.1
                               + echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
                               '
                               + tee /tests/virus/eicar.com
                               + for i in /tests/virus/*
                               ++ clamdscan --stream /tests/virus/Eicar-Test-Signature.zip
                               ++ grep -o FOUND
                               + VIRUS_TEST=FOUND
                               + '[' FOUND == FOUND ']'
                               + echo 'SUCCESS: Clamd working and detecting our test file (/tests/virus/Eicar-Test-Signature.zip)'
                               + for i in /tests/virus/*
                               ++ clamdscan --stream /tests/virus/clam-v2.rar
                               ++ grep -o FOUND
                               + VIRUS_TEST=FOUND
                               + '[' FOUND == FOUND ']'
                               + echo 'SUCCESS: Clamd working and detecting our test file (/tests/virus/clam-v2.rar)'
                               + for i in /tests/virus/*
                               ++ clamdscan --stream /tests/virus/clam-v3.rar
                               ++ grep -o FOU
  data collected               Fri, 19 Oct 2018 15:59:44

Remote Host 'clamd-server-port'
  status                       OK
  monitoring status            Monitored
  monitoring mode              active
  on reboot                    start
  port response time           0.246 ms to 172.26.0.1:3310 type TCP/IP protocol DEFAULT
  data collected               Fri, 19 Oct 2018 15:59:44

File 'clamd-db-main'
  status                       OK
  monitoring status            Monitored
  monitoring mode              active
  on reboot                    start
  permission                   644
  uid                          100
  gid                          101
  size                         112.4 MB
  access timestamp             Fri, 19 Oct 2018 15:59:13
  change timestamp             Fri, 19 Oct 2018 15:59:08
  modify timestamp             Wed, 07 Jun 2017 21:38:00
  data collected               Fri, 19 Oct 2018 15:59:44

File 'clamd-db-daily'
  status                       OK
  monitoring status            Monitored
  monitoring mode              active
  on reboot                    start
  permission                   644
  uid                          100
  gid                          101
  size                         49.1 MB
  access timestamp             Fri, 19 Oct 2018 15:59:08
  change timestamp             Fri, 19 Oct 2018 15:59:08
  modify timestamp             Fri, 19 Oct 2018 13:00:05
  data collected               Fri, 19 Oct 2018 15:59:44

File 'clamd-db-bytecode'
  status                       OK
  monitoring status            Monitored
  monitoring mode              active
  on reboot                    start
  permission                   644
  uid                          100
  gid                          101
  size                         183.0 kB
  access timestamp             Fri, 19 Oct 2018 15:59:22
  change timestamp             Fri, 19 Oct 2018 15:59:08
  modify timestamp             Thu, 09 Aug 2018 00:44:01
  data collected               Fri, 19 Oct 2018 15:59:44

System 'be92aa06e36c'
  status                       OK
  monitoring status            Monitored
  monitoring mode              active
  on reboot                    start
  load average                 [0.33] [0.21] [0.10]
  cpu                          0.1%us 0.1%sy 0.1%wa
  memory usage                 979.5 MB [12.3%]
  swap usage                   0 B [0.0%]
  uptime                       1d 3h 18m
  boot time                    Thu, 18 Oct 2018 12:41:14
  data collected               Fri, 19 Oct 2018 15:59:44
```

# Versioning
Here are the latest releases:

| Docker Tag | Git Hub Release | Clamd Version | Alpine Version |
|-----|-------|-----|--------|
| latest | master  | 0.100.1 | 3.8 |


# TODO


# Issues

If you have any problems with or questions about this image, please contact us through a GitHub issue.

# Contributing

You are invited to contribute new features, fixes, or updates, large or small; we are always thrilled to receive pull requests, and do our best to process them as fast as we can.

Before you start to code, we recommend discussing your plans through a GitHub issue, especially for more ambitious contributions. This gives other contributors a chance to point you in the right direction, give you feedback on your design, and help you find out if someone else is working on the same thing.

# MIT License

Copyright (c) 2018 tspicer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
