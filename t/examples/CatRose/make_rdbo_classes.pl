#!/usr/bin/perl

package My::DB;
use base qw( Rose::DB );

__PACKAGE__->use_private_registry;

__PACKAGE__->register_db(

    driver   => 'sqlite',
    database => 'catrose.db',

);

1;

package main;
use strict;
use warnings;

use Carp;
use Data::Dump qw(pp);
use File::Path;
use File::Basename;
use File::Slurp;
use Path::Class;

# customize for your output
my $base = dir('lib');

require Rose::DB::Object::Loader;

my $loader =
  Rose::DB::Object::Loader->new(
                                db                 => My::DB->new,
                                #db_schema          => 'myschema',
                                class_prefix       => 'CatRose',
                                #exclude_tables     => qr/stuff to skip/,
                                base_classes       => 'CatRose::DB::Object'
                               );

print "making classes\n";

my @classes = $loader->make_classes;

for my $class (@classes)
{

    print $class, "\n";

    my $template = '';
    if ($class->isa('Rose::DB::Object'))
    {
        $template =
          $class->meta->perl_class_definition(braces => 'bsd', indent => 4)
          . "\n";
    }
    else    # Rose::DB::Object::Manager subclasses
    {
        $template = $class->perl_class_definition . "\n";
    }


    (my $file = $class) =~ s,::,/,g;
    $file .= '.pm';

    my ($name, $path, $suffix) = fileparse($file, qr{\.pm});

    my $full = dir($base, $path)->stringify;

    if ($path)
    {
        mkpath([$full], 1);
    }

    write_file(file($base, $file)->stringify, $template) or die "$!\n";

    print "$class written to $file\n";
} 
