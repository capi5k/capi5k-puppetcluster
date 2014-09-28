set :puppet_path, "#{recipes_path}/capi5k-puppetcluster"

load "#{puppet_path}/roles.rb"
load "#{puppet_path}/roles_definition.rb"
load "#{puppet_path}/output.rb"

set :proxy, "https_proxy=http://proxy:3128 http_proxy=http://proxy:3128"
set :apt_get_p, "#{proxy} apt-get"

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
    run "#{proxy} https://raw.githubusercontent.com/pmorillon/puppet-puppet/master/extras/bootstrap/puppet_install.sh | #{env} sh"
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

end
