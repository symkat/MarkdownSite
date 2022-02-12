CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE site (
    id                          serial          PRIMARY KEY,
    repo                        text            not null unique,
    domain                      text            not null unique,
    is_enabled                  boolean         not null default true,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE build (
    id                          serial          PRIMARY KEY,
    site_id                     int             not null references site(id),
    build_dir                   text            not null,
    download_url                text            ,

    -- Status information for the front end.
    is_clone_complete           boolean         not null default false,
    is_build_complete           boolean         not null default false,
    is_deploy_complete          boolean         not null default false,

    is_complete                 boolean         not null default false,
    has_error                   boolean         not null default false,
    error_message               text            ,

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

