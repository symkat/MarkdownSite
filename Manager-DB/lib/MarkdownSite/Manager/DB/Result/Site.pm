use utf8;
package MarkdownSite::Manager::DB::Result::Site;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MarkdownSite::Manager::DB::Result::Site

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::InflateColumn::Serializer>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "InflateColumn::Serializer");

=head1 TABLE: C<site>

=cut

__PACKAGE__->table("site");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'site_id_seq'

=head2 repo

  data_type: 'text'
  is_nullable: 0

=head2 domain

  data_type: 'text'
  is_nullable: 0

=head2 max_static_file_count

  data_type: 'integer'
  default_value: 10
  is_nullable: 0

=head2 max_static_file_size

  data_type: 'integer'
  default_value: 2
  is_nullable: 0

=head2 max_markdown_file_count

  data_type: 'integer'
  default_value: 20
  is_nullable: 0

=head2 minutes_wait_after_build

  data_type: 'integer'
  default_value: 10
  is_nullable: 0

=head2 builds_per_hour

  data_type: 'integer'
  default_value: 3
  is_nullable: 0

=head2 builds_per_day

  data_type: 'integer'
  default_value: 12
  is_nullable: 0

=head2 is_supporter

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 is_enabled

  data_type: 'boolean'
  default_value: true
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "site_id_seq",
  },
  "repo",
  { data_type => "text", is_nullable => 0 },
  "domain",
  { data_type => "text", is_nullable => 0 },
  "max_static_file_count",
  { data_type => "integer", default_value => 10, is_nullable => 0 },
  "max_static_file_size",
  { data_type => "integer", default_value => 2, is_nullable => 0 },
  "max_markdown_file_count",
  { data_type => "integer", default_value => 20, is_nullable => 0 },
  "minutes_wait_after_build",
  { data_type => "integer", default_value => 10, is_nullable => 0 },
  "builds_per_hour",
  { data_type => "integer", default_value => 3, is_nullable => 0 },
  "builds_per_day",
  { data_type => "integer", default_value => 12, is_nullable => 0 },
  "is_supporter",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<site_domain_key>

=over 4

=item * L</domain>

=back

=cut

__PACKAGE__->add_unique_constraint("site_domain_key", ["domain"]);

=head2 C<site_repo_key>

=over 4

=item * L</repo>

=back

=cut

__PACKAGE__->add_unique_constraint("site_repo_key", ["repo"]);

=head1 RELATIONS

=head2 builds

Type: has_many

Related object: L<MarkdownSite::Manager::DB::Result::Build>

=cut

__PACKAGE__->has_many(
  "builds",
  "MarkdownSite::Manager::DB::Result::Build",
  { "foreign.site_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-02-14 15:57:24
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ddij+qgPwKq+xag3eAzgZQ

sub get_builds {
    my ( $self ) = @_;

    return [ map { +{
        id                 => $_->id,
        job_id             => $_->job_id,
        date               => $_->created_at->strftime( "%F %T %Z" ),
    } } $self->search_related( 'builds', { }, { order_by => { -DESC => 'created_at' } } ) ];
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
