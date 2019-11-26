#! /bin/perl -w

my %variables = (
	##### zone
	'zone_name' => 					'digital-pz',
	'zpool' =>  					'digital-pz-data',
	'zpool_size' =>					'',
	'zone_alias' => 				'container',
	'environment' => 				'production',
	'zone_site' => 					'mercier',
	'zone_network_vlan'=>				'1',
	'zone_ip' => 					'158.167.99.125',	
	'netmask_zone_in_slash-notation' => 		'/22',
	'netmask_zone_in_numeric-notation' => 		'255.255.252.0',
	'defaultrouter_ip' =>  				'158.167.96.1',
	'zone_network_interface' => 			'aggr1001',

	##### application
	'application_name' => 				'digital',
	'application_opsrv' => 				'opsrv158',
	'application_ip' => 				'158.167.98.158',
	'netmask_appli_in_slash-notation' => 		'/22',

	##### capping
	'physical_mem_capping' => 			'none',
	'swap_mem_capping' => 				'none',
	'cpu_capping' => 				'none',

	##### cluster
	'cluster_used' => 				'yes',
	'physical_host' => 				'persee',
	'primary_node' => 				'pegase',
	'secondary_node' => 				'persee',

	##### san
	'lun_number' => 				'',

	##### used
	'oracle_used' =>  				'yes',
	'documentum_used' =>  				'no',
	'test_used' =>  				'no',

	##### project
	'appli_project' => 				'digital',
	'appli_project_id' => 				'2310',

	##### application users
	'appli_user' => 				'digital',
	'appli_uid' => 					'60700',
	'w_appli_uid' => 				'60701',

	##### application group
	'appli_group' => 				'digital',
	'appli_gid' => 					'87000'
);

my @workflow = (
	{
		name =>					'demande_ip_zone',
		file => 				'none',
		function => 				'ip_request'
	},
	{
		name =>					'demande_ip_application',
		file => 				'none',
		function => 				'none'
        },
	{
		name =>					'demande_uid_gid_pid',
		file => 				'none',
		function => 				'none'
	},
	{
		name =>					'demande_lun',
		file => 				'none',
		function => 				'lun_request'
	},
	{
		name =>					'zpool_creation',
		file => 				'/home/betorma/docs/solaris_sun/howto_zpool_creation.txt',
		function => 				'none'
	},
	{
		name =>					'zone_installation',
		file => 				'/home/betorma/docs/solaris_sun/howto_zone_zfs_creation.txt',
		function => 				'none'
	},
	{
		name =>					'accounting',
		file => 				'/home/betorma/docs/solaris_sun/howto_zone_user_application.txt',
		function => 				'none'
	},
	{
		name =>					'cluster_integration',
		file => 				'/home/betorma/docs/solaris_sun/howto_cluster_intergration_zone_zfs.txt',
		function => 				'none'
	},
	{
		name =>					'check_nfs_datadomain',
		file => 				'none',
		function => 				'none'
	},
	{
		name =>					'monitoring_zone',
		file => 				'/home/betorma/docs/howto_nagios_add_client.txt',
		function => 				'none'
	},
	{
		name =>					'monitoring_application',
		file => 				'none',
		function => 				'none'
	},
	{
		name =>					'cmdb_zone',
		file => 				'/home/betorma/docs/solaris_sun/howto_zone_cmdb.txt',
		function => 				'none'
	},
	{
		name =>					'capping',
		file => 				'/home/betorma/docs/solaris_sun/howto_zone_capping.txt',
		function => 				'none'
	},
	{
		name =>					'cmdb_capping',
		file => 				'none',
		function => 				'none'
	},
	{
		name =>					'zone_client_backup_creation',
		file => 				'/home/betorma/docs/howto_backup_unix_client_for_zone.txt',
		function => 				'none'
	},
	{
		name =>					'app_client_backup_creation',
		file => 				'/home/betorma/docs/howto_backup_unix_client_for_appli.txt',
		function => 				'none'
	},
	{
		name =>					'rman_client_backup_creation',
		file => 				'/home/betorma/docs/howto_backup_rman_client.txt',
		function => 				'none'
	},
	{
		name =>					'datadomain_share_creation',
		file => 				'none',
		function => 				'datadomain_share_request'
	}
);


my $procedure = '';
my $procedure_owner = 'betorma';
my $email_signature_owner="______________________________________\n
Mathieu Betori
HALIAN
Infrastructures/Exploitation/Systèmes Ouverts de production
UNIX system engineer
______________________________________\n";


sub ip_request() {
	my $to = "To: mathieu.betori\@ext.publications.europa.eu\n";
	my $from = "From: popo\n";
	my $subject = "Subject: demande d'IP pour $variables{zone_name}\n";
	my $type = "Content-Type: text\n";
	my $body = "Bonjour,\n
Pouvez-vous s'il vous plait nous fournir une adresse IP pour la zone $variables{zone_name} et un opsrv pour son application, sur le vlan $variables{zone_network_vlan} ?\n
Merci d'avance.\n
";
	send_mail($to, $from, $subject, $type, $body);
}


sub lun_request() {
	my $to = "To: mathieu.betori\@ext.publications.europa.eu\n";
	my $from = "From: popo\n";
	my $subject = "Subject: demande de lun pour $variables{zone_name}\n";
	my $type = "Content-Type: text\n";
	my $body = "Bonjour,\n
Pouvez-vous s'il vous plait nous fournir la volumetrie suivante:

<< lun_request_table for $variables{zpool_size} >>

Merci d'avance.\n
";
	send_mail($to, $from, $subject, $type, $body);
}


sub datadomain_share_request() {
	my $to = "To: mathieu.betori\@ext.publications.europa.eu\n";
	my $from = "From: popo\n";
	my $subject = "Subject: demande de share datadomain pour $variables{zone_name}\n";
	my $type = "Content-Type: text\n";
	my $body = "Bonjour,\n
Pouvez-vous s'il vous plait creer un share nfs sur le datadomain pour ....

Merci d'avance.\n
";
	send_mail($to, $from, $subject, $type, $body);

}


sub concat() {
	my $workflow_size = @workflow;

	for ($i=0;$i<$workflow_size;$i++) {
		if (($workflow[$i]{file}) && ($workflow[$i]{file} ne 'none')) {
			open(FILE, $workflow[$i]{file}) || die "$workflow[$i]{file}: $!\n";
			while(<FILE>) {
				$procedure .= $_;
			}
			close(FILE);
		}
		if (($workflow[$i]{function}) && ($workflow[$i]{function} ne 'none')) {
			$procedure .= $workflow[$i]{function}();
		}
	}
}


sub replace() {
	foreach (keys(%variables)) {
		#print "remplacer <$_> par $variables{$_}\n";
		$procedure =~ s/<$_>/$variables{$_}/g
	}
}


sub send_mail($$$$$) {
	my $to = shift;
	my $from = shift;
	my $subject = shift;
	my $type = shift;
	my $body = shift;
	$body .= $email_signature_owner;

	open(MAIL, "| /usr/lib/sendmail -t");
	print MAIL "$to";
	print MAIL "$from";
	print MAIL "$subject";
	print MAIL "$type";
	print MAIL "$body";
	close(MAIL);
}


sub main() {
	concat();
	replace();
	print "$procedure\n";
}

main;
