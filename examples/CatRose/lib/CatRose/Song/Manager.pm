package CatRose::Song::Manager;

use base qw(Rose::DB::Object::Manager);

use CatRose::Song;

sub object_class { 'CatRose::Song' }

__PACKAGE__->make_manager_methods('songs');

1;

