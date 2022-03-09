# MarkdownSite Setup Manual

This manual explains the types of machines in a MarkdownSite environment and how to initially setup an environment.  MDS runs on four or more hosts.

## Server Type Overview

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

### Design The Network

### Setup The Network

### Enable Monitoring & Metrics

### Testing That It All Works


