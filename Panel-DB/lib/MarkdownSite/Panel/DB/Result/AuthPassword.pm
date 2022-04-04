use utf8;
package MarkdownSite::Panel::DB::Result::AuthPassword;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MarkdownSite::Panel::DB::Result::AuthPassword

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

=head1 TABLE: C<auth_password>

=cut

__PACKAGE__->table("auth_password");

=head1 ACCESSORS

=head2 person_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 password

  data_type: 'text'
  is_nullable: 0

=head2 salt

  data_type: 'text'
  is_nullable: 0

=head2 updated_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "person_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "password",
  { data_type => "text", is_nullable => 0 },
  "salt",
  { data_type => "text", is_nullable => 0 },
  "updated_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<auth_password_person_id_key>

=over 4

=item * L</person_id>

=back

=cut

__PACKAGE__->add_unique_constraint("auth_password_person_id_key", ["person_id"]);

=head1 RELATIONS

=head2 person

Type: belongs_to

Related object: L<MarkdownSite::Panel::DB::Result::Person>

=cut

__PACKAGE__->belongs_to(
  "person",
  "MarkdownSite::Panel::DB::Result::Person",
  { id => "person_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-04-01 23:10:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+x006K80TywKJeqqU6Zj7Q

__PACKAGE__->set_primary_key('person_id');

use Crypt::Eksblowfish::Bcrypt qw( bcrypt_hash en_base64 de_base64 );
use Crypt::Random;

sub check_password {
    my ( $self, $password ) = @_;
    return de_base64($self->password) eq bcrypt_hash({
            key_nul => 1,
            cost => 8,
            salt => de_base64($self->salt),
    }, $password );
}

sub set_password {
    my ( $self, $password ) = @_;
    $self->_fill_password( $password );
    $self->insert;
    return $self;
}

sub update_password {
    my ( $self, $password ) = @_;
    $self->_fill_password( $password );
    $self->update;
    return $self;
}

sub _fill_password {
    my ( $self, $password ) = @_;

    my $salt = random_salt();

    $self->password(
        en_base64(
            bcrypt_hash({
                key_nul => 1,
                cost => 8,
                salt => $salt,
            }, $password )
        )
    );

    $self->salt( en_base64($salt) );
}

sub random_salt {
    Crypt::Random::makerandom_octet( Length => 16 );
}

1;
