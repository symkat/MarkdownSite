use utf8;
package MarkdownSite::Manager::DB::Result::Build;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MarkdownSite::Manager::DB::Result::Build

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

=head1 TABLE: C<build>

=cut

__PACKAGE__->table("build");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'build_id_seq'

=head2 site_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 build_dir

  data_type: 'text'
  is_nullable: 0

=head2 download_url

  data_type: 'text'
  is_nullable: 1

=head2 is_clone_start

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 is_clone_end

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 is_clone_error

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 clone_error

  data_type: 'text'
  is_nullable: 1

=head2 is_build_start

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 is_build_end

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 is_build_error

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 build_error

  data_type: 'text'
  is_nullable: 1

=head2 is_deploy_start

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 is_deploy_end

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 is_deploy_error

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 deploy_error

  data_type: 'text'
  is_nullable: 1

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
    sequence          => "build_id_seq",
  },
  "site_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "build_dir",
  { data_type => "text", is_nullable => 0 },
  "download_url",
  { data_type => "text", is_nullable => 1 },
  "is_clone_start",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_clone_end",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_clone_error",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "clone_error",
  { data_type => "text", is_nullable => 1 },
  "is_build_start",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_build_end",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_build_error",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "build_error",
  { data_type => "text", is_nullable => 1 },
  "is_deploy_start",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_deploy_end",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_deploy_error",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "deploy_error",
  { data_type => "text", is_nullable => 1 },
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

=head1 RELATIONS

=head2 build_logs

Type: has_many

Related object: L<MarkdownSite::Manager::DB::Result::BuildLog>

=cut

__PACKAGE__->has_many(
  "build_logs",
  "MarkdownSite::Manager::DB::Result::BuildLog",
  { "foreign.build_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 site

Type: belongs_to

Related object: L<MarkdownSite::Manager::DB::Result::Site>

=cut

__PACKAGE__->belongs_to(
  "site",
  "MarkdownSite::Manager::DB::Result::Site",
  { id => "site_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-02-14 15:57:24
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:g7MKA80DNm1laiZInCFs3Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration

sub get_build_logs {
    my ( $self ) = @_;

    return [ map { +{
        event => $_->event,
        line  => $_->detail,
        extra => $_->extra,
        date  => $_->created_at->strftime( "%F %T %Z" ),
    } } $self->search_related( 'build_logs', { }, { order_by => { -ASC => 'created_at' } } ) ];
}
1;
