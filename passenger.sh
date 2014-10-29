#!/usr/bin/env bash

if ! [ -n "$PASSENGER_VERSION" ]; then export PASSENGER_VERSION="4.0.53"; fi

apt -y install apache2 ruby1.8-dev rubygems libcurl4-openssl-dev libssl-dev zlib1g-dev apache2-threaded-dev libapr1-dev libaprutil1-dev
a2enmod ssl
a2enmod headers
a2enmod version
gem install passenger -v $PASSENGER_VERSION

passenger-install-apache2-module --auto

mkdir -p /usr/share/puppet/rack/puppetmasterd
mkdir /usr/share/puppet/rack/puppetmasterd/public /usr/share/puppet/rack/puppetmasterd/tmp
cp /usr/share/puppet/ext/rack/config.ru /usr/share/puppet/rack/puppetmasterd/
chown puppet:puppet /usr/share/puppet/rack/puppetmasterd/config.ru

install_dir=$(gem env |grep "INSTALLATION DIRECTORY" | cut -d':' -f2)
passenger_root="$install_dir/gems/passenger-$PASSENGER_VERSION"
passenger_ruby=$(gem env |grep "RUBY EXECUTABLE" | cut -d':' -f2)

cat << EOF > /etc/apache2/sites-available/puppetmaster
# Debian/Ubuntu:
# TODO make it generic more generic : ruby / passenger version
LoadModule passenger_module $passenger_root/buildout/apache2/mod_passenger.so
PassengerRoot $passenger_root
PassengerRuby $passenger_ruby

# And the passenger performance tuning settings:
# Set this to about 1.5 times the number of CPU cores in your master:
PassengerMaxPoolSize 12
# Recycle master processes after they service 1000 requests
PassengerMaxRequests 1000
# Stop processes if they sit idle for 10 minutes
PassengerPoolIdleTime 600

Listen 8140
<VirtualHost *:8140>
# Make Apache hand off HTTP requests to Puppet earlier, at the cost of
# interfering with mod_proxy, mod_rewrite, etc. See note below.
PassengerHighPerformance On

SSLEngine On

# Only allow high security cryptography. Alter if needed for compatibility.
SSLProtocol ALL -SSLv2 -SSLv3
SSLCipherSuite EDH+CAMELLIA:EDH+aRSA:EECDH+aRSA+AESGCM:EECDH+aRSA+SHA384:EECDH+aRSA+SHA256:EECDH:+CAMELLIA256:+AES256:+CAMELLIA128:+AES128:+SSLv3:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!DSS:!RC4:!SEED:!IDEA:!ECDSA:kEDH:CAMELLIA256-SHA:AES256-SHA:CAMELLIA128-SHA:AES128-SHA
#    SSLHonorCipherOrder     on

SSLCertificateFile      /var/lib/puppet/ssl/certs/$(hostname).pem
SSLCertificateKeyFile   /var/lib/puppet/ssl/private_keys/$(hostname).pem
SSLCertificateChainFile /var/lib/puppet/ssl/ca/ca_crt.pem
SSLCACertificateFile    /var/lib/puppet/ssl/ca/ca_crt.pem
SSLCARevocationFile     /var/lib/puppet/ssl/ca/ca_crl.pem
#    SSLCARevocationCheck    chain
SSLVerifyClient         optional
SSLVerifyDepth          1
SSLOptions              +StdEnvVars +ExportCertData

# Apache 2.4 introduces the SSLCARevocationCheck directive and sets it to none
# which effectively disables CRL checking. If you are using Apache 2.4+ you must
# specify 'SSLCARevocationCheck chain' to actually use the CRL.

# These request headers are used to pass the client certificate
# authentication information on to the puppet master process
RequestHeader set X-SSL-Subject %{SSL_CLIENT_S_DN}e
RequestHeader set X-Client-DN %{SSL_CLIENT_S_DN}e
RequestHeader set X-Client-Verify %{SSL_CLIENT_VERIFY}e

DocumentRoot /usr/share/puppet/rack/puppetmasterd/public

<Directory /usr/share/puppet/rack/puppetmasterd/>
Options None
AllowOverride None
# Apply the right behavior depending on Apache version.
<IfVersion < 2.4>
Order allow,deny
Allow from all
</IfVersion>
<IfVersion >= 2.4>
Require all granted
</IfVersion>
</Directory>

ErrorLog /var/log/apache2/puppet-server.error.log
CustomLog /var/log/apache2/puppet-server.ssl_access.log combined
</VirtualHost>
EOF

a2ensite puppetmaster
update-rc.d -f puppetmaster remove
service puppetmaster stop
/etc/init.d/apache2 restart
