use utf8;
package MarkdownSite::Panel::DB::Result::Builder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MarkdownSite::Panel::DB::Result::Builder

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

=head1 TABLE: C<builder>

=cut

__PACKAGE__->table("builder");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'builder_id_seq'

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 doc_url

  data_type: 'text'
  is_nullable: 1

=head2 img_url

  data_type: 'text'
  is_nullable: 1

=head2 job_name

  data_type: 'text'
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
    sequence          => "builder_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "doc_url",
  { data_type => "text", is_nullable => 1 },
  "img_url",
  { data_type => "text", is_nullable => 1 },
  "job_name",
  { data_type => "text", is_nullable => 0 },
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

=head2 sites

Type: has_many

Related object: L<MarkdownSite::Panel::DB::Result::Site>

=cut

__PACKAGE__->has_many(
  "sites",
  "MarkdownSite::Panel::DB::Result::Site",
  { "foreign.builder_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-04-20 15:44:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lbWnE445FCmDsxTNcCde+Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
