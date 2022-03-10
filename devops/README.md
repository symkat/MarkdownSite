# MarkdownSite Dev/Ops

## Overview

This directory contains devops tools for setting up and maintaining a MarkdownSite installation.

See the `setup/` directory for a guide to getting started with an installation.

See the `config/` directory for a guide to setting up configuration management with ansible.

If you are using this repo to manage a network, you should consider putting the configuration in its own branch and removing the `.gitignore` files that prevent config files from being saved.

## Graphs For Common Events

You will encounter this graph in the `setup/` directory showing the components of the setup.

```mermaid
flowchart TB
    subgraph one[panel.markdownsite.com]
        a1["Source Of Truth<br> for MDS & Minion.<br>(PostgreSQL)"]
        a2["Serve markdownsite.com.<br>(nginx w/ ssl as reverse proxy)"]
        a3["Daemon for markdownsite.<br>(MDS::Manager via hypnotoad)"]
        a4["send stats to insight server.<br>(collectd)"]
    end

    subgraph two[build-01.markdownsite.com]
        b1["Website Builder & Deploy.<br>(MDS::Manager minion worker)"]
        b2["send stats to insight server.<br>(collectd)"]

    end

    subgraph three[webserver-01.markdownsite.com]
        c1["Serves Static HTML,<br>unknown requests<br>sent to<br>Markdownsite::CGI.<br>(lighttpd)"]
        c2["Markdown Renderer<br> & Caching.<br>(MarkdownSite::CGI)"]
        c3["send stats to insight server.<br>(collectd)"]

    end

    subgraph four[insight.markdownsite.com]
        d1["Receive stats,<br> write to graphite.<br>(collectd)"]
        d2["Accept stats from<br> collectd and store.<br>(carbon-cache)"]
        d3["Provide a web interface<br> for ops to see graphs.<br>(grafana)"]
        d4["Provide a web interface<br> for ops to see metrics.<br>(graphite-web)"]
    end
```

The following guides explain the relationships in various situations.

### Handle request to build repository

```mermaid
flowchart TB
    subgraph one[panel.markdownsite.com]
        a1["Source Of Truth<br> for MDS & Minion.<br>(PostgreSQL)"]
        a2["Serve markdownsite.com.<br>(nginx w/ ssl as reverse proxy)"]
        a3["Daemon for markdownsite.<br>(MDS::Manager via hypnotoad)"]
        a4["send stats to insight server.<br>(collectd)"]
    end

    subgraph two[build-01.markdownsite.com]
        b1["Website Builder & Deploy.<br>(MDS::Manager minion worker)"]
        b2["send stats to insight serve.r<br>(collectd)"]

    end

    subgraph three[webserver-01.markdownsite.com]
        c1["Serves Static HTML,<br>unknown requests<br>sent to<br>Markdownsite::CGI.<br>(lighttpd)"]
        c2["Markdown Renderer<br> & Caching.<br>(MarkdownSite::CGI)"]
        c3["send stats to insight server.<br>(collectd)"]

    end

    z1[User Computer] -- STEP 1: HTTP Request To Import --> a2
    a2 -- STEP 2: Pass request --> a3
    a3 -- STEP 3: Create repo if not exist --> a1
    a3 -- STEP 4: Make minion job to deploy website --> a1

    b1 <-- STEP 5: Minion worker gets job --> a1
    b1 --  STEP 6: Minion deploys webroot, config, reloads lighty--> three
```

### Handle request to serve website

If the file exists, the following path will be taken:

```mermaid
flowchart TB

    subgraph three[webserver-01.markdownsite.com]
        c1["Serves Static HTML,<br>unknown requests<br>sent to<br>Markdownsite::CGI.<br>(lighttpd)"]
        c2["Markdown Renderer<br> & Caching.<br>(MarkdownSite::CGI)"]
        c3["send stats to insight server.<br>(collectd)"]

    end

    z1[User Computer: request foo.markdownsite.net] -->
    z2[DNS Resolves *.markdownsite.net -> webserver-01.markdownsite.com]
    z2 -- STEP 1: HTTP Request --> c1
    c1 -- STEP 2: Does var/www/foo.markdownsite.net/html/index.html exists? --> z3
    z3[Yes] --> z4[Serve Static File]
```

If the file does not exist, the following path will be taken:

```mermaid
flowchart TB

    subgraph three[webserver-01.markdownsite.com]
        c1["Serves Static HTML,<br>unknown requests<br>sent to<br>Markdownsite::CGI.<br>(lighttpd)"]
        c2["Markdown Renderer<br> & Caching.<br>(MarkdownSite::CGI)"]
        c3["send stats to insight server.<br>(collectd)"]

    end

    z1[User Computer: request foo.markdownsite.net] -->
    z2[DNS Resolves *.markdownsite.net -> webserver-01.markdownsite.com]
    z2 -- STEP 1: HTTP Request --> c1
    c1 -- STEP 2: Does /var/www/foo.markdownsite.net/html/index.html exists? --> z3
    z3[No] -- STEP 3: Invoke markdownsite.cgi--> c2
    c2 -- Does markdownsite.cgi know about this url? -->  z4[YES]
    z4 -- "STEP 4: Store markdownsite.cgi HTML body as<br>/var/www/foo.markdownsite.net/html/index.html<br>so future requests are served from disk."
    --> z5["Serve content to end user"]
    c2 --> z6[No] --> z7[Serve HTTP 404 to end user]
```


certbot --nginx -d markdownsite.com -d www.markdownsite.com -n --agree-tos --email youATdomain.com
```




## Testing The Setup


## Resetting the DB

The database can be clean reset with the panel-reset-db.yml playbook.

```bash
ansible-playbook -i '45.33.35.224,' panel-reset-db.yml
```

## Backup & Restore

### Backing up Grafana

Login to the server and stop the service with `systemctl stop grafana-server`, and then download the `/var/lib/grafana/grafana.db` file.

### Restoring Grafana From Backup

Login to the server and stop the service with `systemctl stop grafana-server`, and then upload the database backup to `/var/lib/grafana/grafana.db` and restart with `systemctl start grafana-server`.

### Backing up MarkdownSite

Login to the panel or a build server and run `mds-manager db-dump > backup-YYYY-MM-DD.sql`.


### Restore MarkdownSite From Backup

Use the `setup/` guide to create a new network.  Replace the `Manager-DB/etc/schema.sql` file with your backup.

