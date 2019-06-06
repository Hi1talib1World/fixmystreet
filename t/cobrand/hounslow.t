use FixMyStreet::TestMech;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $hounslow_id = $mech->create_body_ok(2483, 'Hounslow Borough Council')->id;

$mech->create_problems_for_body(1, $hounslow_id, 'An old problem made before Hounslow FMS launched', {
    confirmed => '2018-12-25 09:00',
    lastupdate => '2018-12-25 09:00',
});
$mech->create_problems_for_body(1, $hounslow_id, 'A brand new problem made on the Hounslow site', {
    cobrand => 'hounslow'
});
$mech->create_problems_for_body(1, $hounslow_id, 'A brand new problem made on fixmystreet.com', {
    cobrand => 'fixmystreet'
});

subtest "it still shows old reports on fixmystreet.com" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'fixmystreet',
    }, sub {
        $mech->get_ok('/reports/Hounslow');

        $mech->content_contains('An old problem made before Hounslow FMS launched');
        $mech->content_contains('A brand new problem made on the Hounslow site');
        $mech->content_contains('A brand new problem made on fixmystreet.com');
    };
};

subtest "it does not show old reports on Hounslow" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'hounslow',
    }, sub {
        $mech->get_ok('/reports/Hounslow');

        $mech->content_lacks('An old problem made before Hounslow FMS launched');
        $mech->content_contains('A brand new problem made on the Hounslow site') or diag $mech->content;
        $mech->content_contains('A brand new problem made on fixmystreet.com');
    };
};

done_testing();
