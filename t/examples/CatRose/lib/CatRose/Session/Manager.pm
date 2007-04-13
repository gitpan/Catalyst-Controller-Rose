package CatRose::Session::Manager;

use base qw(Rose::DB::Object::Manager);

use CatRose::Session;

sub object_class { 'CatRose::Session' }

__PACKAGE__->make_manager_methods('sessions');

1;

