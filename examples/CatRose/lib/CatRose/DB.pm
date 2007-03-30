package CatRose::DB;
use strict;
use warnings;
use base qw( Rose::DB );

__PACKAGE__->use_private_registry;

__PACKAGE__->register_db(
    domain   => __PACKAGE__->default_domain,
    type     => __PACKAGE__->default_type,
    driver   => 'sqlite',
    database => $ENV{DB_PATH} || 'catrose.db',

    #host     => 'localhost',
    #username => 'joeuser',
    #password => 'mysecret',
                        );

1;
