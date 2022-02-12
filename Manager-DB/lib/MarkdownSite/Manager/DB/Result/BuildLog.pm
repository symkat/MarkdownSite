use utf8;
package MarkdownSite::Manager::DB::Result::BuildLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MarkdownSite::Manager::DB::Result::BuildLog

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

=head1 TABLE: C<build_log>

=cut

__PACKAGE__->table("build_log");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'build_log_id_seq'

=head2 build_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 event

  data_type: 'text'
  is_nullable: 0

=head2 detail

  data_type: 'text'
  is_nullable: 1

=head2 extra

  data_type: 'json'
  is_nullable: 1
  serializer_class: 'JSON'

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
    sequence          => "build_log_id_seq",
  },
  "build_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "event",
  { data_type => "text", is_nullable => 0 },
  "detail",
  { data_type => "text", is_nullable => 1 },
  "extra",
  { data_type => "json", is_nullable => 1, serializer_class => "JSON" },
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

=head2 build

Type: belongs_to

Related object: L<MarkdownSite::Manager::DB::Result::Build>

=cut

__PACKAGE__->belongs_to(
  "build",
  "MarkdownSite::Manager::DB::Result::Build",
  { id => "build_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-02-07 00:07:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wJGHrsrecuh63c5/Grfoow


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
