use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'Catalyst::Controller::Rose',
    VERSION_FROM      => 'lib/Catalyst/Controller/Rose.pm', # finds $VERSION
    PREREQ_PM         => {

          'Data::Pageset'      => '0.01',
          'Sort::SQL'          => '0.01',
          'JSON::Syck'         => '0.01',


    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Catalyst/Controller/Rose.pm', # retrieve abstract from module
       AUTHOR         => 'Peter Karman <pkarman@localdomain>') : ()),
);
