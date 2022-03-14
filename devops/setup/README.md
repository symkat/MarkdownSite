# MarkdownSite Setup Manual

This manual explains the types of machines in a MarkdownSite environment and how to initially setup an environment.  MDS runs on four or more hosts.

## Machine Type Overview

| Server    | Purpose                                                                   |
| --------- | ------------------------------------------------------------------------- |
| Panel     | Hosts MarkdownSite.com, PostgreSQL for site config and minion queue.      |
| Build     | Minion workers: build websites and push them to webservers for hosting.   |
| Webserver | Hosts markdownsites, static generated sites, etc                          |
| Insight   | Graphite, Grafana, Collectd. Receive metrics, graph things, gain insight. |

### Panel

The panel server hosts the actual website that gives the interface for people to submit git repositories to.

The web interface is provided by MarkdownSite::Manager, a Mojolicious application.  The source of truth is a postgresql database named markdownsite.  An additional postgresql database, minion, is used by the Minion job queue.

The database must be accessable from all build nodes.

### Build

The build server runs a minion worker.  The worker is provided by MarkdownSite::Manager.

This server runs jobs that are queued on the minion postgresql database on the Panel host.  It checks out git repositories, performs build steps, and then pushes the complete website to one or more webservers.

This node must have SSH access to WebServer nodes.  This node must have PSQL access to the Panel node.

### WebServer

The WebServer hosts markdownsite and static generated sites.

Sites composed of markdown files use MarkdownSite::CGI to generate and cache HTML versions of their site.  Sites composed of statically generated content are directly served.

Lighttpd is used for the webserver.

### Insight

The Insight server provides a platform for collecting and analysing metrics.  It receives metrics from collectd and writes them to a time series database.  Metrics can be explored with Graphite and Grafana.

## Setup

The initial installation of MarkdownSite is done in this directory using the `setup` script.  The setup script runs ansible roles for the machine type and is customized with the `config.yml` file.

### Design The Network

MarkdownSite should run one panel server, one insight server, and may run any amount of build and webservers.

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

If one choose, this pattern can be repeated with build nodes expanding out and scaling.  Web server nodes can be expanded out to handle increased network traffic.  This current design requires all webserver nodes to have the same data loaded locally, therefore each webserver must be able to serve the whole of the network traffic itself.  Webserver nodes are load balanced by adding each one as a DNS record.

WebServer nodes can be scaled up by bringing a new, bigger, webserver node up, adding it to the deploy list, running the build\_markdownsite minion job for each domain on the server, and then adding it to the DNS rotation.  The smaller machine can be dropped from DNS, and the server can be removed once the insight server shows no traffic is being served.

### Configure The Setup

As a first step, copy `config.yml.example` to `config.yml`.  Read this file carefully and add your changes.  This file controls all of the initial setup, database configuration, ssh keys, authentication information.  Once it has been written, the network can be setup.


### Setup The Network

The setup script should fully configure a machine.  It takes the machine type, the IP or hostname that SSH can connect to the machine on, and the hostname that the machine should be set to.

Consider this, the MarkdownSite network.  The network runs on markdownsite.com, and user websites are hosted on markdownsite.net.

| Server Type | Domain                   | IP Address     |
| ----------- | ------------------------ | -------------- |
| Panel       | panel.markdownsite.com   | 45.33.35.224   |
| Insight     | insight.markdownsite.com | 45.33.47.240   |
| Build       | bl01-ca.markdownsite.com | 45.79.99.161   |
| Web Server  | ws01-ca.markdownsite.com | 192.155.87.155 |
| Web Server  | ws01-nj.markdownsite.com | 97.107.132.241 |

If one wanted to build this, after having written `config.yml`, the following commands would do so:

The following commands would bring up the initial network state, after having written `config.yml`:

```bash
#       Ansible Role        Host/IP To Connect       Hostname to set the machine to
./setup mds-setup-panel     panel.markdownsite.com   panel.markdownsite.com
./setup mds-setup-webserver 192.155.87.155.com       ws01-ca.markdownsite.com
./setup mds-setup-webserver 192.155.87.155           ws01-nj.markdownsite.com
./setup mds-setup-build     bl01-ca.markdownsite.com bl01-ca.markdownsite.com
./setup mds-setup-insight   insight.markdownsite.com insight.markdownsite.com
```

One would then set the following DNS records.

| Domain                    | IP Address       | Real Server              |
| ------------------------- | ---------------- | ------------------------ |
| markdownsite.com          | 45.33.35.224     | panel.markdownsite.com   |
| www.markdownsite.com      | 45.33.35.224     | panel.markdownsite.com   |
| panel.markdownsite.com    | 45.33.35.224     | panel.markdownsite.com   |
| insight.markdownsite.com  | 45.33.47.240     | insight.markdownsite.com |
| grafana.markdownsite.com  | 45.33.47.240     | insight.markdownsite.com |
| graphite.markdownsite.com | 45.33.47.240     | insight.markdownsite.com |
| bl01-ca.markdownsite.com  | 45.79.99.161     | bl01-ca.markdownsite.com |
| ws01-ca.markdownsite.com  | 192.155.87.155   | ws01-ca.markdownsite.com |
| ws01-nj.markdownsite.com  | 97.107.132.241   | ws01-nj.markdownsite.com |
| markdownsite.net          | 192.155.87.155   | ws01-ca.markdownsite.com |
| markdownsite.net          | 97.107.132.241   | ws01-nj.markdownsite.com |
| \*.markdownsite.net       | markdownsite.net | CNAME Record             |

This completes the initial setup of a MarkdownSite instance.

To configure SSL and collectd continue to the `config/` directory.

### Testing That It All Works

If all is well:

1. The panel will be accessable and a git repository can be added.
2. Once submitted, it will show a status page and build progress for the repo.
3. The minion job will have completed successfully.
4. The build website will be accessable.

## Wrappping Up

The network should now be up and handling traffic.

## Trouble Shooting



