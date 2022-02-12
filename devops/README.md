## Installing MarkdownSite

This guide documents how to install MarkdownSite.  It is written from the perspective of working on markdownsite.com and serving content from markdownsite.net.  Substituting out IP addresses and domain names should result in this working for another cluster.

## DNS

You will want to setup the following:

| Domain Name            | Server | IP Address     | Private IP      |
| ---------------------- | ------ | -------------- | =============== |
| serve.markdownsite.com | Serve  | 192.155.87.155 | 192.168.143.35  |
| build.markdownsite.com | Build  | 45.79.99.161   | 192.168.212.133 |
| panel.markdownsite.com | Panel  | 45.33.35.224   | 192.168.192.220 |
| www.markdownsite.com   | Panel  | 45.33.35.224   | 192.168.192.220 |
| markdownsite.com       | Panel  | 45.33.35.224   | 192.168.192.220 |

## Configure

The configuration file `config.yml` should be created.  There is a sample file that may be viewed.

## Build

Packages for MarkdownSite::CGI, MarkdownSite::Manager, and MarkdownSite::Manager::DB need to be added to the appropriate locations:

For the Panel server:
```
ansible/roles/markdownsite-panel/files/builds/MarkdownSite-Manager-DB-1.tar.gz
ansible/roles/markdownsite-panel/files/builds/MarkdownSite-Manager-0.001.tar.gz
```

For the Build server:
```
ansible/roles/markdownsite-build/files/builds/MarkdownSite-Manager-DB-1.tar.gz
ansible/roles/markdownsite-build/files/builds/MarkdownSite-Manager-0.001.tar.gz
```

For the Serve server:
```
ansible/roles/markdownsite-serve/files/builds/MarkdownSite-CGI-0.001.tar.gz
```

SSH Keys need to be at the appropriate locations:

For the Panel server:
```
ansible/roles/markdownsite-panel/files/id_rsa
```

For the Build server:
```
ansible/roles/markdownsite-build/files/id_rsa/id_rsa_ansible.pub
ansible/roles/markdownsite-build/files/id_rsa/id_rsa_ansible
ansible/roles/markdownsite-build/files/id_rsa/id_rsa_deploy.pub
ansible/roles/markdownsite-build/files/id_rsa/id_rsa_deploy
```

## Do Installation

One can now run ansible to install the system.  Each playbook may take 15-45 minutes to run, and one could choose to run them all at the same time in alternative terminals.


```bash
ansible-playbook -i '192.155.87.155,' install-serve.yml
```

```bash
ansible-playbook -i '45.79.99.161,' install-build.yml
```

```bash
ansible-playbook -i '45.33.35.224,' install-panel.yml

# Setup SSL
ssh root@45.33.35.224
certbot --nginx -d markdownsite.com -d www.markdownsite.com -n
```

## Testing The Setup


