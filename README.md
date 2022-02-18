See devops/ for install instructions


## Management Commands

MarkdownSite includes command line tools to manage hosted sites.  These commands are invoked by calling `mds-manager command`.

| Command    | Description                                          |
| ---------- | ---------------------------------------------------- |
| list-sites | Show the id, domain, and repository of hosted sites. |
| edit-site  | Change the configuration of a hosted site.           |
| show-site  | Show the config and build logs for a hosted site.    |
| dbc        | Connect to the DB ( < schema.sql works, too )        |
| db-dump    | Dump the markdownsite DB with pg\_dump               |


## Diagrams

Note: You may need to tab away and back for these diagrams to render.

### Operating Overview

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


