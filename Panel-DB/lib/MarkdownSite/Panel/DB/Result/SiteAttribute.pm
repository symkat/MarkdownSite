use utf8;
package MarkdownSite::Panel::DB::Result::SiteAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MarkdownSite::Panel::DB::Result::SiteAttribute

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

=head1 TABLE: C<site_attribute>

=cut

__PACKAGE__->table("site_attribute");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'site_attribute_id_seq'

=head2 site_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 value

  data_type: 'json'
  default_value: '{}'
  is_nullable: 0
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
    sequence          => "site_attribute_id_seq",
  },
  "site_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "value",
  {
    data_type        => "json",
    default_value    => "{}",
    is_nullable      => 0,
    serializer_class => "JSON",
  },
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

=head2 C<unq_site_id_name>

=over 4

=item * L</site_id>

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("unq_site_id_name", ["site_id", "name"]);

=head1 RELATIONS

=head2 site

Type: belongs_to

Related object: L<MarkdownSite::Panel::DB::Result::Site>

=cut

__PACKAGE__->belongs_to(
  "site",
  "MarkdownSite::Panel::DB::Result::Site",
  { id => "site_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-04-01 23:10:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lLZxnVDFiLuqE2zXJ+XjyQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
