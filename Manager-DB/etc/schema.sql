CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE site (
    id                          serial          PRIMARY KEY,
    repo                        text            not null unique,
    domain                      text            not null unique,

    -- Settings: File Allowances
    max_static_file_count       int             not null default 10,
    max_static_file_size        int             not null default  2,
    max_markdown_file_count     int             not null default 20,

    -- Settings: Build Timers
    minutes_wait_after_build    int             not null default 10,
    builds_per_hour             int             not null default 3,
    builds_per_day              int             not null default 12,

    -- Settings: Repo owner supports us on GitHub Sponsers
    is_supporter                boolean         not null default false,

    is_enabled                  boolean         not null default true,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE build (
    id                          serial          PRIMARY KEY,
    site_id                     int             not null references site(id),
    build_dir                   text            not null,
    download_url                text            ,

    -- Status information for the front end / Result::Build should have
    -- ->build_status that makes a structure that makes sense from these
    -- values for build started | complete | error, and then for each
    -- stage of the process as well.  _error fields will be exposed to the
    -- end user.
    is_clone_start              boolean         not null default false,
    is_clone_end                boolean         not null default false,
    is_clone_error              boolean         not null default false,
    clone_error                 text            ,

    is_build_start              boolean         not null default false,
    is_build_end                boolean         not null default false,
    is_build_error              boolean         not null default false,
    build_error                 text            ,

    is_deploy_start             boolean         not null default false,
    is_deploy_end               boolean         not null default false,
    is_deploy_error             boolean         not null default false,
    deploy_error                text            ,

    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE build_log (
    id                          serial          PRIMARY KEY,
    build_id                    int             not null references build(id),
    event                       text            not null,
    detail                      text            ,
    extra                       json            ,
    created_at                  timestamptz     not null default current_timestamp
);

