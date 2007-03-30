package CatRose::Model::Album;
use strict;
use warnings;

use base qw( Catalyst::Model::RDBO );

__PACKAGE__->config('name' => 'CatRose::Album');

1;
