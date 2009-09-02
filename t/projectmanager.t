use strict;
use warnings;
use lib 'lib';
use Test::More tests => 4;

BEGIN { use_ok 'Hugme::ProjectManager' }

my $p = Hugme::ProjectManager->new();
is_deeply [$p->admins('json')], [ sort ( "viklund", "moritz_", "masak") ],
          'can ge admins for jsonp';
is $p->owner('json'), 'moritz', 'can get owner';
is $p->url('json'),   'http://github.com/moritz/json/',
    'can get URL for json';
