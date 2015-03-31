set :puppet_path, "#{recipes_path}/capi5k-puppetcluster"

require 'erb'

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
    puppet
    master::default
    clients::default
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
      configure::default
    end

    task :install, :roles => [:puppet_master] do
      set :user, "root"
      run "apt-get -y install puppetmaster=#{PUPPET_VERSION}-1puppetlabs1 puppetmaster-common=#{PUPPET_VERSION}-1puppetlabs1"
    end

    task :ip, :roles => [:puppet_master] do
      ip = capture("facter ipaddress")
      puts ip
      File.write("#{puppet_path}/tmp/ipmaster", ip)
    end
    
    namespace :configure do
     
      task :default do
        fix
        generate
        transfer       
      end

      task :fix, :roles => [:puppet_master] do
        run "rm -rf /var/lib/puppet/yaml"
      end


      task :generate do
        agents = find_servers :roles => [:puppet_clients]
        @agents = agents.map{|a| a.host}
        template = File.read("#{puppet_path}/templates/autosign.conf.erb")
        renderer = ERB.new(template, nil, '-<>')
        generate = renderer.result(binding)
        myFile = File.open("#{puppet_path}/tmp/autosign.conf", "w")
        myFile.write(generate)
        myFile.close
      end

      task :transfer, :roles => [:puppet_master] do
        set :user, "root"
        upload "#{puppet_path}/tmp/autosign.conf", "/etc/puppet/autosign.conf", :via => :scp
        run "service puppetmaster restart"
      end

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
      ipmaster = File.read("#{puppet_path}/tmp/ipmaster").delete("\n")
      run "echo '\n #{ipmaster} puppet' >> /etc/hosts"
    end

    desc 'Certificate request'
    task :certs, :roles => [:puppet_clients] do
      set :user, "root"   
      run "puppet agent --test" 
    end

  end # clients


  namespace :passenger do
    # it follows https://docs.puppetlabs.com/guides/passenger.html
    desc 'Add passenger support for the puppet master'
    task :default do
      install
    end

    task :install, :roles => [:puppet_master] do
      set :user, "root"
      upload "#{puppet_path}/passenger.sh", "passenger.sh", :via => :scp
      env = " #{proxy}"
      run "#{env} sh passenger.sh" 
    end

  end


end
