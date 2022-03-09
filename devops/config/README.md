# MarkdownSite Configuration Management

This directory provides on-going configuration management for MarkdownSite instances after they have been setup.

A role is provided to install and configure collectd on each MarkdownSite server so that it sends metrics to an insight server.


Create an inventory file named `production.yml`

```yaml
all:
  hosts:
    panel:
      ansible_host: x.x.x.x
    build-01:
      ansible_host: x.x.x.x
    webserver-01:
      ansible_host: x.x.x.x
```

Create a host\_var file for each server instance, for example `host_vars/panel`, `host_vars/webserver-01`.

```yaml
ollectd_host: metrics.hostname
collectd_user: User
collectd_pass: Password
```

When complete, the directory listing should appear roughly as follows:

```
.
├── host_vars
│   ├── build-01
│   ├── panel
│   └── webserver-01
├── production.yml
├── README.md
├── roles
│   └── mds-collectd
│       ├── files
│       │   └── collectd.service
│       ├── tasks
│       │   └── main.yml
│       └── templates
│           └── collectd.conf.j2
└── site.yml

6 directories, 9 files
```

Use ansible-playbook to configure everything:

```bash
ansible-playbook -i production.yml site.yml
```
