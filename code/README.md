# rp-study code

We fetch from, archive to, and process collected data on a single shared
Linux server.  Automated tasks are controlled through a designated user
crontab with most custom tools located in the `/net/data/rpki/bin`
directory unless otherwise noted.  Raw publication point (PP) log data
is fetched then stored under the `/net/data/rpki/pp` directory
corresponding to the log message type (e.g. connect), PP name and
service protocol (RRDP or rsync).  Post-processed log data is stored as
corresponding CSV files under `/net/data/rpki/bin/processed`
corresponding to log message type, PP name, and service protocol.
Post-processed data is then bulk-imported to InfluxDB.

The following list summarizes the specific data, details, and tools as
apprproriate.

* [bin/](bin/)
  This directory contains all the shared scripts and tools used drive
  the automated fetching and processing of log data.

* [crontab](crontab/)
  We control periodic fetching and daily processing of our PPs access
  logs through cron jobs on a collector/processing system.

* [influxdb.schema](influxdb.schema)
  A text summary of our InfluxDB schema.

* [notebooks](notebooks)
  A directory of Juypter notebooks and data used to produce the graphs
  in the IMC 2020 [On Measuring RPKI Relying
  Parties (https://doi.org/10.1145/3419394.3423622) paper.
