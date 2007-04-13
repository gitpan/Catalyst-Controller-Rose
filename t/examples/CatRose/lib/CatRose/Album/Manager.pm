package CatRose::Album::Manager;

use base qw(Rose::DB::Object::Manager);

use CatRose::Album;

sub object_class { 'CatRose::Album' }

__PACKAGE__->make_manager_methods('albums');

1;

