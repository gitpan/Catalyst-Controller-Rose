package CatRose::Song;

use strict;

use base qw(CatRose::DB::Object);

__PACKAGE__->meta->setup(
    table => 'songs',

    columns => [
                id     => {type => 'integer'},
                title  => {type => 'varchar', length => 128},
                artist => {type => 'varchar', length => 128},
                length => {type => 'varchar', length => 16},
               ],

    primary_key_columns => ['id'],

    relationships => [

        albums => {
                   map_class => 'CatRose::AlbumSong',
                   type      => 'many to many',
                  },

      ]

);

1;

