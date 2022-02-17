CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE site (
    id                          serial          PRIMARY KEY,
    repo                        text            not null unique,
    domain                      text            not null unique,

    -- Settings: File Allowances
    max_static_file_count       int             not null default 10,
    max_static_file_size        int             not null default  2, -- MiB
    max_markdown_file_count     int             not null default 20,

    -- Settings: Build Timers
    minutes_wait_after_build    int             not null default 10,
    builds_per_hour             int             not null default 3,
    builds_per_day              int             not null default 12,

    -- Settings: Repo owner supports us on GitHub Sponsers.
    is_supporter                boolean         not null default false,

    is_enabled                  boolean         not null default true,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE build (
    id                          serial          PRIMARY KEY,
    site_id                     int             not null references site(id),
    job_id                      int             not null, -- For minion->job($id)
    build_dir                   text            not null,
    created_at                  timestamptz     not null default current_timestamp
);
