package CatRose::Album;

use strict;

use base qw(CatRose::DB::Object);

__PACKAGE__->meta->setup(
    table => 'albums',

    columns => [
                id     => {type => 'integer'},
                title  => {type => 'varchar', length => 128},
                artist => {type => 'varchar', length => 128},
               ],

    primary_key_columns => ['id'],

    relationships => [

        songs => {
                  map_class => 'CatRose::AlbumSong',
                  type      => 'many to many',
                 },

    ]
);

sub combo
{
    my $self = shift;
    return '' unless $self->title or $self->artist;
    return join(' : ', $self->title || '', $self->artist || '');
}

1;

