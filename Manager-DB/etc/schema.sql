CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE site (
    id                          serial          PRIMARY KEY,
    repo                        citext          not null unique,
    domain                      citext          not null unique,

    -- Settings: File Allowances
    max_static_file_count       int             not null default 100,
    max_static_file_size        int             not null default   2, -- MiB
    max_static_webroot_size     int             not null default  50, -- MiB
    max_markdown_file_count     int             not null default  20,

    -- Settings: Build Timers
    minutes_wait_after_build    int             not null default 10,
    builds_per_hour             int             not null default  3,
    builds_per_day              int             not null default 12,

    -- Settings: Features
    build_priority              int             not null default 1,
    can_change_domain           boolean         not null default false,

    is_enabled                  boolean         not null default true,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE build (
    id                          serial          PRIMARY KEY,
    site_id                     int             not null references site(id),
    job_id                      int             not null, -- For minion->job($id)
    created_at                  timestamptz     not null default current_timestamp
);
