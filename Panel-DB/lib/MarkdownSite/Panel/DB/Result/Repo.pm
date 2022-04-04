use utf8;
package MarkdownSite::Panel::DB::Result::Repo;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MarkdownSite::Panel::DB::Result::Repo

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

=head1 TABLE: C<repo>

=cut

__PACKAGE__->table("repo");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'repo_id_seq'

=head2 site_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 url

  data_type: 'text'
  is_nullable: 0

=head2 auth

  data_type: 'text'
  is_nullable: 0

=head2 username

  data_type: 'text'
  is_nullable: 1

=head2 password

  data_type: 'text'
  is_nullable: 1

=head2 private_key

  data_type: 'text'
  is_nullable: 1

=head2 public_key

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
    sequence          => "repo_id_seq",
  },
  "site_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "url",
  { data_type => "text", is_nullable => 0 },
  "auth",
  { data_type => "text", is_nullable => 0 },
  "username",
  { data_type => "text", is_nullable => 1 },
  "password",
  { data_type => "text", is_nullable => 1 },
  "private_key",
  { data_type => "text", is_nullable => 1 },
  "public_key",
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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-04-04 14:48:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:khCwpe5hlos8aeFhBIsECg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
