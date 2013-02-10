#
# Cookbook Name:: haproxy
# Recipe:: app_lb
#
# Copyright 2011, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

pool_members = {}
node['haproxy']['app_server_roles'].each do |app_server_role|
	pool_members[app_server_role] = search("node", "role:#{app_server_role} AND chef_environment:#{node.chef_environment}") || []
	# load balancer may be in the pool
	pool_members[app_server_role] << node if node.run_list.roles.include?(app_server_role)
end

# we prefer connecting via local_ipv4 if
# pool members are in the same cloud
# TODO refactor this logic into library...see COOK-494
pool_members.each_pair do |app_server_role,members|
  members.map! do |member|
    server_ip = begin
      if member.attribute?('cloud')
        if node.attribute?('cloud') && (member['cloud']['provider'] == node['cloud']['provider'])
           member['cloud']['local_ipv4']
        else
          member['cloud']['public_ipv4']
        end
      else
        member['ipaddress']
      end
    end
    {:ipaddress => server_ip, :hostname => member['hostname']}
  end
end

package "haproxy" do
  action :install
end

cookbook_file "/etc/default/haproxy" do
  source "haproxy-default"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[haproxy]"
end

template "/etc/haproxy/haproxy.cfg" do
  source "haproxy-app_lb.cfg.erb"
  owner "root"
  group "root"
  mode 00644
  variables(
    :pool_members => pool_members,
    :defaults_options => defaults_options,
    :defaults_timeouts => defaults_timeouts
  )
  notifies :reload, "service[haproxy]"
end

service "haproxy" do
  supports :restart => true, :status => true, :reload => true
  action [:enable, :start]
end
