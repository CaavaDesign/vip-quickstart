$plugins = ['developer', 'jetpack', 'mrss']

# Install WordPress
exec {"wp install /srv/www/wp":
	command => "/usr/bin/wp core multisite-install --base='vip.dev' --title='vip.dev' --admin_email='wordpress@vip.dev' --admin_name='wordpress' --admin_password='wordpress'",
	cwd => '/srv/www/wp',
	require => [
		Vcsrepo['/srv/www/wp'],
		Class['wp::cli'],
	]
}

# Install plugins
wp::plugin { $plugins:
	location    => '/srv/www/wp',
	networkwide => true,
	require => Exec['wp install /srv/www/wp']
}

# Install default theme
exec { '/usr/bin/wp theme install twentyfourteen':
	unless => '/usr/bin/wp theme is-installed twentyfourteen',
	require => Exec['wp install /srv/www/wp'],
}

# Install VIP recommended developer plugins
wp::command { 'developer install-plugins':
	command  => 'developer install-plugins --type=wpcom-vip --activate',
	location => '/srv/www/wp',
	require  => Wp::Plugin['developer']
}

# Update all the plugins
wp::command { 'plugin update --all':
	command  => 'plugin update --all',
	location => '/srv/www/wp',
	require => Exec['wp install /srv/www/wp']
}

# Install WP-CLI
class { wp::cli:
	ensure => installed,
	install_path => '/srv/www/wp-cli',
	version => '0.12.1'
}

# VCS Checkout
vcsrepo { '/srv/www/wp':
	ensure   => 'present',
	source   => 'http://core.svn.wordpress.org/trunk/',
	provider => svn,
}

vcsrepo { '/srv/www/wp-content/themes/vip/plugins':
	ensure   => 'present',
	source   => 'https://vip-svn.wordpress.com/plugins/',
	provider => svn,
	basic_auth_username => $svn_username,
	basic_auth_password => $svn_password,
}

vcsrepo { '/srv/www/wp-content/themes/pub':
	ensure   => 'present',
	source   => 'https://wpcom-themes.svn.automattic.com/',
	provider => svn,
}

vcsrepo { '/srv/www/wp-tests':
	ensure   => 'present',
	source   => 'http://develop.svn.wordpress.org/trunk/',
	provider => svn,
}

# Create a local config
file { 'local-config.php':
	ensure => present,
	path   => '/srv/www/local-config.php',
	notify => Exec['generate salts']
}

exec { 'generate salts':
	command => 'printf "<?php\n" > /srv/www/local-config.php; curl https://api.wordpress.org/secret-key/1.1/salt/ >> /srv/www/local-config.php',
	refreshonly => true
}
