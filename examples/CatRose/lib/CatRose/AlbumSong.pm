package CatRose::AlbumSong;
use strict;
use warnings;
use base qw( CatRose::DB::Object );

__PACKAGE__->meta->setup(
    table => 'album_songs',

    columns => [
                album_id => {type => 'integer', not_null => 1},
                song_id  => {type => 'integer', not_null => 1}
               ],

    foreign_keys => [
        song  => {class => 'CatRose::Song',  key_columns => {song_id  => 'id'}},
        album => {class => 'CatRose::Album', key_columns => {album_id => 'id'}}
                    ]

);

1;
