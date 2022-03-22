package FixMyStreet::Cobrand::Thamesmead;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area { return 'Thamesmead'; }
sub council_name { return 'Thamesmead'; }
sub council_url { return 'thamesmead'; }
sub council_area_id { return '0000'; }


sub admin_user_domain {
    'thamesmeadnow.org.uk'
}

sub default_map_zoom { 6 }

1;
