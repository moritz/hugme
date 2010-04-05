use strict;
use warnings;
use WWW::Mechanize;
use File::Slurp qw(slurp);

my ($new_email, $new_nick) = @ARGV;
die "Usage: $0 <email> <nickname>\n" unless $new_email && $new_nick;

my $m = WWW::Mechanize->new();
$m->get('http://commitbit.pugscode.org/');

if ($m->content =~ /not currently signed in/) {
    $m->get('http://commitbit.pugscode.org/login');

    use JSON qw(from_json);
    my $auth = from_json(slurp('pugs-auth.json'));
    $m->submit_form(
        fields  => {
            'J:A:F-email-loginbox'      => $auth->{user},
            'J:A:F-password-loginbox'   => $auth->{password},
        }
    );
}

$m->get('http://commitbit.pugscode.org/admin/project/Pugs/people');
$m->submit_form(
    fields  => {
        'J:A:F-person-auto-9f1dcd24cb6bc918cae446d1dc8b986e-1'   => $new_email,
        'J:A:F-nickname-auto-9f1dcd24cb6bc918cae446d1dc8b986e-1' => $new_nick,
    }
);
