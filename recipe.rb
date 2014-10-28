set :puppet_path, "#{recipes_path}/capi5k-puppetcluster"

load "#{puppet_path}/roles.rb"
load "#{puppet_path}/roles_definition.rb"
load "#{puppet_path}/output.rb"

set :proxy, "https_proxy=http://proxy:3128 http_proxy=http://proxy:3128"
set :apt_get_p, "#{proxy} apt-get"
set :gem_p, "#{proxy} gem"

PUPPET_VERSION=puppet_version

namespace :puppetcluster do
  
  desc 'Install a puppet cluster' 
  task :default, :on_error => :continue do
    rubygems
    puppet
    master::default
    clients::default
    sign_all
  end
  
  task :rubygems, :roles => [:puppet_master, :puppet_clients], :on_error => :continue do
    set :user, "root"
    run "#{apt_get_p} install -y rubygems" 
  end


  task :puppet, :roles => [:puppet_master, :puppet_clients] do
    set :user, "root"
    env = "PUPPET_VERSION=#{PUPPET_VERSION}"
    env += " #{proxy}"
    run "#{apt_get_p} update && #{apt_get_p} install -y curl" 
    run "#{proxy} curl -L https://raw.githubusercontent.com/pmorillon/puppet-puppet/master/extras/bootstrap/puppet_install.sh | #{env} sh"
  end

  namespace :master do

    desc 'Install the puppet master'
    task :default do
      install
      ip
    end

    task :install, :roles => [:puppet_master],  :on_error => :continue do
      set :user, "root"
      run "apt-get -y install puppetmaster=#{PUPPET_VERSION}-1puppetlabs1 puppetmaster-common=#{PUPPET_VERSION}-1puppetlabs1"
      run "puppet agent -t"
    end

    task :ip, :roles => [:puppet_master] do
      ip = capture("facter ipaddress")
      puts ip
      File.write("tmp/ipmaster", ip)
    end

  end

  namespace :clients do 
    
    desc 'Install the clients'
    task :default do
      install
      certs
    end

    task :install, :roles => [:puppet_clients] do
      set :user, "root"
      # pupet has been installed before
      ipmaster = File.read("tmp/ipmaster").delete("\n")
      run "echo '\n #{ipmaster} puppet' >> /etc/hosts"
    end

    task :certs, :roles => [:puppet_clients], :on_error => :continue do
      set :user, "root"   
      run "puppet agent --test" 
    end

  end # clients

  desc 'Sign all pending certificates'
  task :sign_all, :roles => [:puppet_master] do
    set :user, "root"
    run "puppet cert sign --all" 
  end

  namespace :passenger do
    # it follows https://docs.puppetlabs.com/guides/passenger.html
    desc 'Add passenger support for the puppet master'
    task :default do
      install
      config
      vhost_generate
      vhost_enable
      start
    end

    desc 'Install apache2 and passenger'
    task :install, :roles => [:puppet_master] do
      set :user, "root"
      run "#{apt_get_p} -y install apache2 ruby1.8-dev rubygems"
      run "a2enmod ssl"
      run "a2enmod headers"
      run "#{gem_p} install rack passenger"
      # missing headers (required by the installer)
      run "#{apt_get_p} -y install libcurl4-openssl-dev libssl-dev zlib1g-dev apache2-threaded-dev libapr1-dev libaprutil1-dev"
      run "passenger-install-apache2-module --auto"
    end

    desc 'Configure apache2 to use passenger'
    task :config, :roles => [:puppet_master] do
      set :user, "root"
      run "mkdir -p /usr/share/puppet/rack/puppetmasterd"
      run "mkdir /usr/share/puppet/rack/puppetmasterd/public /usr/share/puppet/rack/puppetmasterd/tmp"
      run "cp /usr/share/puppet/ext/rack/config.ru /usr/share/puppet/rack/puppetmasterd/"
      run "chown puppet:puppet /usr/share/puppet/rack/puppetmasterd/config.ru"
    end

    task :vhost_generate do
      template = File.read("#{puppet_path}/templates/puppetmaster.erb")
      renderer = ERB.new(template)
      @puppet_master = find_servers(:roles => [:puppet_master]).first
      generate = renderer.result(binding)
      myFile = File.open("#{puppet_path}/tmp/puppetmaster", "w")
      myFile.write(generate)
      myFile.close
    end

    task :vhost_enable, :roles => [:puppet_master] do
      set :user, "root"
      upload  "#{puppet_path}/tmp/puppetmaster", "/etc/apache2/sites-available/puppetmaster", :via => :scp
      run "a2ensite puppetmaster"
    end

    task :start, :roles => [:puppet_master] do
      set :user, "root"
      # remove boot startup
      run "update-rc.d -f puppetmaster remove"
      run "service puppetmaster stop"
      run "/etc/init.d/apache2 restart"
    end


  end


end
