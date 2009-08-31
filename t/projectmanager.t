use strict;
use warnings;
use lib 'lib';
use Test::More tests => 2;
BEGIN { use_ok 'Hugme::ProjectManager' }

my $p = Hugme::ProjectManager->new();
is_deeply [$p->admins('json')], [ sort ( "viklund", "moritz_", "masak") ],
          'can ge admins for "proto"';
