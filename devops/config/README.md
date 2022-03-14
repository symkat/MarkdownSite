# MarkdownSite Configuration Management

This directory provides on-going configuration management once a MarkdownSite instance has been setup.

It is recommended that you create a branch to manage this configuration in.  It will contain configuration secrets, so be mindful of where, if anywhere, it is pushed.

## Getting Started

Bring the `config.yml` file you used during the setup process into this directory.  All of those values will then be available here.

You will need to setup an inventory file.

Consider the following network:

| Server Type | Domain                   |
| ----------- | ------------------------ |
| Panel       | panel.markdownsite.com   |
| Insight     | insight.markdownsite.com |
| Build       | bl01-ca.markdownsite.com |
| Web Server  | ws01-ca.markdownsite.com |
| Web Server  | ws01-nj.markdownsite.com |

One panel and insight server (it would be very unusual to have more than one of either).  One build server in the California datacenter, and two web servers, one in California and another in New Jearsy.

The following inventory file, named `production.yml`, should then be made:

```yaml
all:
  hosts:
  children:
    panels:
      hosts:
        panel.markdownsite.com:
    insights:
      hosts:
        insight.markdownsite.com:
    webservers:
      hosts:
        ws01-ca.markdownsite.com:
        ws01-nj.markdownsite.com:
    buildservers:
      hosts:
        bl01-ca.markdownsite.com:
```

It is important to ensure that all of these records exist in DNS.

Each host can have configuration specific to itself.  This is done with a file named after the hostname in the directory `host_vars/`.

```
~/MarkdownSite/devops/config$ tree host_vars/
host_vars/
    ├── bl01-ca.markdownsite.com.yml
    ├── insight.markdownsite.com.yml
    ├── panel.markdownsite.com.yml
    ├── ws01-ca.markdownsite.com.yml
    └── ws01-nj.markdownsite.com.yml

0 directories, 5 files
```

Each file should contain at least the collectd credentials that were set during `setup/`.

```yaml
collectd_host: ip.addr.here.foo
collectd_user: .....
collectd_pass: ...........................
```

## Configure SSL

By default, SSL is not setup when MarkdownSite is created with the setup programs.  This is to keep development instances as easy to setup as possible.  SSL can be enabled after installation and managed here.

This guide assumes the use of Let's Encrypt.  It uses certbot and the linode dns plugin to accomplish a dns challenge to get certificates for `markdownsite.com`, `*.markdownsite.com`, `markdownsite.net`, and `*.markdownsite.net`.


### Getting the certificates

Ensure that you have run `apt-get install python3-certbot-dns-linode` to get certbot setup.

Edit `letsencrypt/.credentials` and add your linode API key.  The key needs permissions: read access on account, read/write on domains.

Then run the following.  Make sure you change out the domain name with your own set.

```bash
cd roles/mds-ssl/files

certbot --config-dir `pwd`/letsencrypt                      \
    --logs-dir `pwd`/letsencrypt/logs                       \
    --work-dir `pwd`/letsencrypt/logs                       \
    certonly                                                \
    --agree-tos                                             \
    --dns-linode                                            \
    --non-interactive                                       \
    --register-unsafely-without-email                       \
    --dns-linode-credentials `pwd`/letsencrypt/.credentials \
    --dns-linode-propagation-seconds 180                    \
    -d '*.markdownsite.net'                                 \
    -d markdownsite.net

certbot --config-dir `pwd`/letsencrypt                      \
    --logs-dir `pwd`/letsencrypt/logs                       \
    --work-dir `pwd`/letsencrypt/logs                       \
    certonly                                                \
    --agree-tos                                             \
    --dns-linode                                            \
    --non-interactive                                       \
    --register-unsafely-without-email                       \
    --dns-linode-credentials `pwd`/letsencrypt/.credentials \
    --dns-linode-propagation-seconds 180                    \
    -d '*.markdownsite.com'                                 \
    -d markdownsite.com
```
### Next Steps

Once the certificates are in place, SSL will automatically be configured by the mds-ssl role.

* Build servers will use an ssl-specific lighty config.
* The webserver will use ssl for all hosted sites.
* Grafana will be protected by ssl.
* Graphite will be protected by ssl.
* MarkdownSite will be protected by ssl.

## Run the config

Use ansible-playbook to configure everything:

```bash

# Configure everything
ansible-playbook -i production.yml site.yml

# Configure only bl01-ca.markdownsite.com
ansible-playbook -i production.yml  -l bl01-ca.markdownsite.com site.yml

```

## Testing

### Test HTTPS Per Host

If you have multiple webserver nodes and want to check how a specific one is responding, use something like the following:

```bash
 curl -D - --connect-to os-example.markdownsite.net:443:ws01-ca.markdownsite.com:443   https://os-example.markdownsite.net
 ```

 This will check the site `os-example.markdownsite.net`, and it will direct the traffic to the webserver node `ws01-ca.markdownsite.com`.
