require 'bundler/setup'
require 'rubygems'
require 'xp5k'
require 'erb'

XP5K::Config.load

set :site, ENV['site'] || "lyon"
set :walltime, ENV['walltime'] || "05:00:00"

$myxp = XP5K::XP.new(:logger => logger)

$myxp.define_job({
  :resources  => ["nodes=2, walltime=#{walltime}"],
  :site       => "#{site}",
  :retry      => true,
  :goal       => "100%",
  :types      => ["deploy"],
  :name       => "init" , 
  :roles      =>  [
    XP5K::Role.new({ :name => 'capi5k-init', :size => 2 }),
  ],

  :command    => "sleep 86400"
})

$myxp.define_deployment({
  :site           => "#{site}",
  :environment    => "wheezy-x64-nfs",
  :roles          => %w(capi5k-init),
  :key            => File.read("#{ssh_public}"), 
})

load "config/deploy/xp5k_common_tasks.rb"
