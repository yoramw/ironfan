#
# Cookbook Name::       big_package
# Description::         Base configuration for big_package
# Recipe::              default
# Author::              Philip (flip) Kromer - Infochimps, Inc
#
# Copyright 2011, Philip (flip) Kromer - Infochimps, Inc
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

node[:pkg_sets][:install].map!(&:to_s)

node[:pkg_sets][:pkgs].each do |set_name, pkgs|
  next unless node[:pkg_sets][:install].include?(set_name.to_s)
  pkgs.each do |pkg|
    pkg = { :name => pkg } if pkg.is_a?(String)
    package pkg[:name] do
      version   pkg[:version] if pkg[:version]
      source    pkg[:source]  if pkg[:source]
      options   pkg[:options] if pkg[:options]
      action    pkg[:action] || :install
    end
  end
end

node[:pkg_sets][:gems].each do |set_name, gems|
  next unless node[:pkg_sets][:install].include?(set_name.to_s)
  gems.each do |gem|
    gem = { :name => gem } if gem.is_a?(String)
    gem_package gem[:name] do
      version   gem[:version] if gem[:version]
      source    gem[:source]  if gem[:source]
      options   gem[:options] if gem[:options]
      action    gem[:action] || :install
    end
  end
end
