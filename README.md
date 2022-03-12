# MarkdownSite - Create a website from a git repo in one click.

![MarkdownSite Homepage](https://markdownsite.com/img/markdownsite.jpg)

This is the codebase for [MarkdownSite](https://markdownsite.com/), an open-source hosting platform for static sites and markdown files.

## What Is MarkdownSite?



## How do I use MarkdownSite?



## Understanding MarkdownSite

```mermaid
flowchart TB
    subgraph one[Panel Node]
    a1[PostgresSQL]
    a2[MarkdownSite::Manager Daemon]
    a3[Nginx]
    a1 <-- MarkdownSite::Manager::DB / Minion--> a2
    a3 -- Hypnotoad PSGI --> a2

    end
    subgraph two[Build Node]
    b1[Clone & Build Website]
    b2[MarkdownSite::Manager Worker]
    b2 <-- PSQL Private IP --> a1
    end
    subgraph three[Serve Node]
    c1[Lighttpd]
    c2[Static Files]
    c3[MarkdownSite::CGI]
    c1 <-- Static File Exists --> c2
    c1 <-- No File Exists--> c3
    c3 -- Generate & Store HTML Page From Markdown--> c2  
    end

    b1 -- Ansible SSH--> three
    q[Internet User] <-- View Hosted Website -->c1
    z[MarkdownSite User] <-- Submit Git Repo For Hosting -->a3
```


## OPs CheatSheet

MarkdownSite includes command line tools to manage hosted sites.  These commands are invoked by calling `mds-manager command`.

| Command    | Description                                          |
| ---------- | ---------------------------------------------------- |
| list-sites | Show the id, domain, and repository of hosted sites. |
| edit-site  | Change the configuration of a hosted site.           |
| dbc        | Connect to the DB ( < schema.sql works, too )        |
| db-dump    | Dump the markdownsite DB with pg\_dump               |


When one uses list-stes they will get a listing of the websites:

```bash
manager@panel:~/markdownsite$ mds-manager list-sites
ID   Domain                           Repository
1    foobar.markdownsite.net          git@gitea.simcop2387.info:MarkdownSite/foobar.markdownsite.net.git
4    vcbodxru.markdownsite.net        https://github.com/Perl/perl5.git
2    os-example.markdownsite.net      git@github.com:symkat/os-example.markdownsite.com.git
3    hugo-example.markdownsite.net    git@github.com:symkat/hugo.markdownsite.net.git
5    4spxrrfv.markdownsite.net        git@github.com:symkat/hello.markdownsite.net.git
```

To get more details on any of the sites, use `edit-site`

```
manager@panel:~/markdownsite$ mds-manager edit-site --site 3
Domain  : hugo-example.markdownsite.net
Repo    : git@github.com:symkat/hugo.markdownsite.net.git
Site id : 3
Created : 2022-03-12 03:23:32
Status: : Enabled

==========================================
                  Config Value   Old   New
==========================================
                build_priority     1     1
                builds_per_day    12    12
               builds_per_hour    10    10
             can_change_domain     1     1
       max_markdown_file_count    20    20
         max_static_file_count   100   100
          max_static_file_size     2     2
       max_static_webroot_size    50    50
      minutes_wait_after_build     0     0
```

Config values can be changed by prepending `--` to them in the command and providing a value.

```bash
manager@panel:~/markdownsite$ mds-manager edit-site --site 3 --minutes_wait_after_build 2
Domain  : hugo-example.markdownsite.net
Repo    : git@github.com:symkat/hugo.markdownsite.net.git
Site id : 3
Created : 2022-03-12 03:23:32
Status: : Enabled

==========================================
                  Config Value   Old   New
==========================================
                build_priority     1     1
                builds_per_day    12    12
               builds_per_hour    10    10
             can_change_domain     1     1
       max_markdown_file_count    20    20
         max_static_file_count   100   100
          max_static_file_size     2     2
       max_static_webroot_size    50    50
      minutes_wait_after_build     0     2
```

If your terminal supports colors, the config lines that changed will be displayed in green.

Commands have associated help files, invoke by calling `--help`

```bash
manager@panel:~/markdownsite$ mds-manager edit-site --help
"/usr/local/bin/mds-manager edit-site <search option>  [--setting value]";

This program shows information about a markdown site and allows
the settings to be edited.

Use a search option to find a site, like --domain foobar.markdownsite.net,
or --site 5 to display the settings for a given site.
...
OPTIONS

These options can be used to change the behavior of the site.

    --max_static_file_count       | How many files a webroot may have.

    --max_static_file_size        | File size limit per file in MiB.
...
```


