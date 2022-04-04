CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE person (
    id                          serial          PRIMARY KEY,
    name                        text            not null,
    email                       citext          not null unique,
    is_enabled                  boolean         not null default true,
    created_at                  timestamptz     not null default current_timestamp
);

-- Settings for a given user.  | Use with care, add things to the data model when you should.
create TABLE person_settings (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null references person(id),
    name                        text            not null,
    value                       json            not null default '{}',
    created_at                  timestamptz     not null default current_timestamp,

    -- Allow ->find_or_new_related()
    CONSTRAINT unq_person_id_name UNIQUE(person_id, name)
);

CREATE TABLE auth_password (
    person_id                   int             not null unique references person(id),
    password                    text            not null,
    salt                        text            not null,
    updated_at                  timestamptz     not null default current_timestamp,
    created_at                  timestamptz     not null default current_timestamp
);

CREATE TABLE auth_token (
    id                          serial          PRIMARY KEY,
    person_id                   int             not null references person(id),
    token                       text            not null,
    created_at                  timestamptz     not null default current_timestamp
);

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

-- Attributes for a given machine.  | Use with care, add things to the data model when you should.
create TABLE site_attribute (
    id                          serial          PRIMARY KEY,
    site_id                     int             not null references site(id),
    name                        text            not null,
    value                       json            not null default '{}',
    created_at                  timestamptz     not null default current_timestamp,

    -- Allow ->find_or_new_related()
    CONSTRAINT unq_site_id_name UNIQUE(site_id, name)
);

CREATE TABLE build (
    id                          serial          PRIMARY KEY,
    site_id                     int             not null references site(id),
    job_id                      int             not null, -- For minion->job($id)
    created_at                  timestamptz     not null default current_timestamp
);
