package CatRose::Session;

use strict;

use base qw(CatRose::DB::Object);

__PACKAGE__->meta->setup
(
    table   => 'sessions',

    columns => 
    [
        id           => { type => 'character', length => 72 },
        session_data => { type => 'text' },
        expires      => { type => 'integer' },
    ],

    primary_key_columns => [ 'id' ],
);

1;

