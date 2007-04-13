package CatRose::Model::Song;
use strict;
use warnings;

use base qw( Catalyst::Model::RDBO );

__PACKAGE__->config('name' => 'CatRose::Song');

1;
