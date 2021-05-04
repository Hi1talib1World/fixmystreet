use utf8;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use CGI::Simple;
use Path::Tiny;
use Test::MockModule;

my $sample_file = path(__FILE__)->parent->child("sample.jpg");
ok $sample_file->exists, "sample file $sample_file exists";

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2217, 'Buckinghamshire Council', {
    send_method => 'Open311', api_key => 'key', endpoint => 'endpoint', jurisdiction => 'fms', can_be_devolved => 1 });
my $contact = $mech->create_contact_ok(body_id => $body->id, category => 'Claim', email => 'CLAIM');

my $geo = Test::MockModule->new('FixMyStreet::Geocode');
$geo->mock('string', sub {
    my $s = shift;
    my $ret = [];
    if ($s eq 'A street') {
        $ret = { latitude => 51.81386, longitude => -0.82973, address => 'A street, Bucks' };
    }
    return $ret;
});

my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
$ukc->mock('_fetch_features', sub {
    my ($self, $cfg, $x, $y) = @_;
    is $y, 213450, 'Correct latitude';
    return [
        {
            properties => {
                feature_ty => '4A',
                site_code => 'Road ID'
            },
            geometry => {
                type => 'LineString',
                coordinates => [ [ $x-2, $y+2 ], [ $x+2, $y+2 ] ],
            }
        },
    ];
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'buckinghamshire',
    STAGING_FLAGS => { send_reports => 1 },
    COBRAND_FEATURES => {
        claims => { buckinghamshire => 1 },
        open311_email => { buckinghamshire => { claim => 'claims@example.net' } },
    },
    PHONE_COUNTRY => 'GB',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Report new vehicle claim, report id known' => sub {
        $mech->get_ok('/claims');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { what => 'vehicle', claimed_before => 'Yes' } }, "claim type screen");
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org', phone => '01234 567890', address => "12 A Street\nA Town" } }, "about you screen");
        $mech->submit_form_ok({ with_fields => { fault_fixed => 'No' } }, "fault fixed");
        $mech->submit_form_ok({ with_fields => { fault_reported => 'No' } }, "fault not reported");
        $mech->submit_form_ok({ with_fields => { continue => 'Continue' } }, "go back");
        $mech->submit_form_ok({ with_fields => { fault_reported => 'Yes' } }, "fault reported");
        $mech->submit_form_ok({ with_fields => { report_id => 1 } }, "report id");
        $mech->submit_form_ok({ with_fields => { location => 'A street' } }, 'location details');
        $mech->submit_form_ok({ with_fields => { latitude => 51.81386, longitude => -.82973 } }, 'location details');
        $mech->submit_form_ok({ with_fields => { 'incident_date.year' => 2020, 'incident_date.month' => 10, 'incident_date.day' => 10, incident_time => 'morning' } }, "incident time");
        $mech->submit_form_ok({ with_fields => { weather => 'sunny', direction => 'east', details => 'some details', in_vehicle => 'Yes', speed => '20mph', actions => 'an action' } }, "incident details");
        $mech->submit_form_ok({ with_fields => { witnesses => 'Yes', witness_details => 'some witnesses', report_police => 'Yes', incident_number => 23 } }, "witnesses etc");
        $mech->submit_form_ok({ with_fields => { what_cause => 'bollard', aware => 'Yes', where_cause => 'bridge', describe_cause => 'a cause',
            photos => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
            photos2 => [ $sample_file, undef, Content_Type => 'image/jpeg' ],
        } }, "cause screen");
        $mech->submit_form_ok({ with_fields => { make => 'a car', registration => 'rego!', mileage => '20', v5 => [ $sample_file, undef, Content_Type => 'application/octet-stream', filename => 'v5.jpg' ], v5_in_name => 'Yes', insurer_address => 'insurer address', damage_claim => 'No', vat_reg => 'No' } }, "car details");
        $mech->submit_form_ok({ with_fields => {
            vehicle_damage => 'the car was broken',
            vehicle_photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            vehicle_photos2 => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            vehicle_receipts => [ $sample_file, undef, Content_Type => 'application/octet-stream', 'repairs.jpg' ],
            tyre_damage => 'Yes', tyre_mileage => 20,
            tyre_receipts => [ $sample_file, undef, Content_Type => 'application/octet-stream' ]
        } }, "damage details");
        $mech->content_contains('Review');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Claim submitted');

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->title, "Claim";
        is $report->bodies_str, $body->id;
        my $expected_detail = <<EOF;
What are you claiming for?: Vehicle damage
Have you ever filed a Claim for damages with Buckinghamshire Council?: Yes
Full name: Test McTest
Telephone number: 01234 567890
Email address: test\@example.org
Address: 12 A Street
A Town
Has the fault been fixed?: No
Have you reported the fault to the Council?: Yes
Fault ID: 1
Postcode, or street name and area of the source: A street
Latitude: 51.81386
Longitude: -0.82973
What day did the incident happen?: 10/10/2020
What time did the incident happen?: morning
Describe the weather conditions at the time: sunny
What direction were you travelling in at the time?: east
Describe the details of the incident: some details
Were you in a vehicle when the incident happened?: Yes
What speed was the vehicle travelling?: 20mph
If you were not driving, what were you doing when the incident happened?: an action
Were there any witnesses?: Yes
Please give the witness’ details: some witnesses
Did you report the incident to the police?: Yes
What was the incident reference number?: 23
What was the cause of the incident?: Bollard
Were you aware of it before?: Yes
Where was the cause of the incident?: Bridge
Describe the incident cause: a cause
Please provide two dated photos of the incident: 74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg,74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg
Make and model: a car
Registration number: rego!
Vehicle mileage: 20
Copy of the vehicle’s V5 Registration Document: sample.jpg
Is the V5 document in your name?: Yes
Name and address of the Vehicle's Insurer: insurer address
Are you making a claim via the insurance company?: No
Are you registered for VAT?: No
Describe the damage to the vehicle: the car was broken
Please provide two photos of the damage to the vehicle: 74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg,74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg
Please provide receipted invoices for repairs: sample.jpg
Are you claiming for tyre damage?: Yes
Age and Mileage of the tyre(s) at the time of the incident: 20
Please provide copy of tyre purchase receipts: sample.jpg
EOF
        is $report->detail, $expected_detail;
        is $report->latitude, 51.81386;
        my $test_data = FixMyStreet::Script::Reports::send();
        my @email = $mech->get_email;
        is $email[0]->header('To'), 'TfB <claims@example.net>';
        my $req = $test_data->{test_req_used};
        is $req, undef, 'Nothing sent by Open311';
        $mech->clear_emails_ok;
    };

    subtest 'Report new vehicle claim, report fixed' => sub {
        $mech->get_ok('/claims');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { what => 'vehicle', claimed_before => 'No' } }, 'claim type');
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org', phone => '01234 567890', address => "12 A Street\nA Town" } }, 'about you details');
        $mech->submit_form_ok({ with_fields => { fault_fixed => 'Yes' } }, 'fault fixed');
        $mech->submit_form_ok({ with_fields => { location => 'A street' } }, 'location details');
        $mech->submit_form_ok({ with_fields => { latitude => 51.81386, longitude => -.82973 } }, 'location details');
        $mech->submit_form_ok({ with_fields => { 'incident_date.year' => 2020, 'incident_date.month' => 10, 'incident_date.day' => 10, incident_time => 'morning' } }, 'incident time');
        $mech->submit_form_ok({ with_fields => { weather => 'sunny', direction => 'east', details => 'some details', in_vehicle => 'Yes', speed => '20mph', actions => 'an action' } }, 'incident details');
        $mech->submit_form_ok({ with_fields => { witnesses => 'Yes', witness_details => 'some witnesses', report_police => 'Yes', incident_number => 23 } }, 'witnesses etc');
        $mech->submit_form_ok({ with_fields => { what_cause => 'other', what_cause_other => '', aware => 'Yes', where_cause => 'bridge', describe_cause => 'a cause', photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ] } }, 'cause details');
        $mech->content_contains('Other cause field is required');
        $mech->submit_form_ok({ with_fields => { what_cause => 'other', what_cause_other => 'Duck', aware => 'Yes', where_cause => 'bridge', describe_cause => 'a cause',
            photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            photos2 => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
        } }, 'cause details');
        $mech->submit_form_ok({ with_fields => { make => 'a car', registration => 'rego!', mileage => '20', v5 => [ $sample_file, undef, Content_Type => 'application/octet-stream' ], v5_in_name => 'Yes', insurer_address => 'insurer address', damage_claim => 'No', vat_reg => 'No' } }, 'vehicle details');
        $mech->submit_form_ok({ with_fields => { vehicle_damage => 'the car was broken',
            vehicle_photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            vehicle_photos2 => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            vehicle_receipts => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            tyre_damage => 'Yes', tyre_mileage => 20,
            tyre_receipts => [ $sample_file, undef, Content_Type => 'application/octet-stream' ]
        } }, 'damage details');
        $mech->content_contains('Review', "Review screen displayed");
        $mech->submit_form_ok({ with_fields => { process => 'summary' } }, "Claim submitted");
        $mech->content_contains('Claim submitted');
        my $test_data = FixMyStreet::Script::Reports::send();
        my @email = $mech->get_email;
        is $email[0]->header('To'), 'TfB <claims@example.net>';
        my $req = $test_data->{test_req_used};
        my $c = CGI::Simple->new($req->content);
        is $c->param('service_code'), 'CLAIM';
        is $c->param('attribute[title]'), 'east';
        is $c->param('attribute[description]'), 'a cause';
        is $c->param('attribute[site_code]'), 'Road ID';
    };

    subtest 'Report new property claim, report id known' => sub {
        $mech->get_ok('/claims');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { what => 'property', claimed_before => 'No' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org', phone => '01234 567890', address => "12 A Street\nA Town" } });
        $mech->submit_form_ok({ with_fields => { fault_fixed => 'No' } });
        $mech->submit_form_ok({ with_fields => { fault_reported => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { report_id => 1 } });
        $mech->submit_form_ok({ with_fields => { location => 'A street' } }, 'location details');
        $mech->submit_form_ok({ with_fields => { latitude => 51.81386, longitude => -.82973 } }, 'location details');
        $mech->submit_form_ok({ with_fields => { 'incident_date.year' => 2020, 'incident_date.month' => 10, 'incident_date.day' => 10, incident_time => 'morning' } });
        $mech->submit_form_ok({ with_fields => { weather => 'sunny', details => 'some details' } });
        $mech->submit_form_ok({ with_fields => { witnesses => 'Yes', witness_details => 'some witnesses', report_police => 'Yes', incident_number => 23 } });
        $mech->submit_form_ok({ with_fields => { what_cause => 'bollard', aware => 'Yes', where_cause => 'bridge', describe_cause => 'a cause',
            photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            photos2 => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
        } });
        $mech->submit_form_ok({ with_fields => { property_insurance => [ $sample_file, undef, Content_Type => 'application/octet-stream' ] } });
        $mech->submit_form_ok({ with_fields => { property_damage_description => 'damage_description',
            property_photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            property_photos2 => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            property_invoices => [ $sample_file, undef, Content_Type => 'application/octet-stream' ]
        } });
        $mech->content_contains('Review');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Claim submitted');
    };

    subtest 'Report new injury claim, report id known' => sub {
        $mech->get_ok('/claims');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { what => 'personal', claimed_before => 'No' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org', phone => '01234 567890', address => "12 A Street\nA Town" } });
        $mech->submit_form_ok({ with_fields => { fault_fixed => 'No' } });
        $mech->submit_form_ok({ with_fields => { fault_reported => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { report_id => 1 } });
        $mech->submit_form_ok({ with_fields => { location => 'A street' } }, 'location details');
        $mech->submit_form_ok({ with_fields => { latitude => 51.81386, longitude => -.82973 } }, 'location details');
        $mech->submit_form_ok({ with_fields => { 'incident_date.year' => 2020, 'incident_date.month' => 10, 'incident_date.day' => 10, incident_time => 'morning' } });
        $mech->submit_form_ok({ with_fields => { weather => 'sunny', direction => 'east', details => 'some details' } });
        $mech->submit_form_ok({ with_fields => { witnesses => 'Yes', witness_details => 'some witnesses', report_police => 'Yes', incident_number => 23 } });
        $mech->submit_form_ok({ with_fields => { what_cause => 'bollard', aware => 'Yes', where_cause => 'bridge', describe_cause => 'a cause',
            photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
            photos2 => [ $sample_file, undef, Content_Type => 'application/octet-stream' ],
        } });
        $mech->submit_form_ok({ with_fields => { 'dob.year' => 1980, 'dob.month' => 5, 'dob.day' => 10, ni_number => 'ni number', occupation => 'occupation', 'employer_contact' => 'employer contact' } });
        $mech->submit_form_ok({ with_fields => { describe_injuries => 'describe injuries', medical_attention => 'Yes', 'attention_date.year' => 2020, 'attention_date.month' => 9, 'attention_date.day' => 23, gp_contact => 'GP contact', absent_work => 'Yes', absence_dates => 'absence dates', ongoing_treatment => 'Yes', treatment_details => 'treatment details' } });
        $mech->content_contains('Review');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Claim submitted');
    };
};

done_testing;