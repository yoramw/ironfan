module ClusterChef
  class Cluster

    def discover!
      @aws_instance_hash = {}
      discover_cluster_chef!
      discover_chef_nodes!
      discover_fog_servers!
    end

  protected

    def fog_servers
      @fog_servers ||= ClusterChef.fog_servers.select{|fs| fs.groups.index(cluster_name.to_s) && (fs.state != "terminated") }
    end

    def chef_nodes
      return @chef_nodes if @chef_nodes
      @chef_nodes = []
      Chef::Search::Query.new.search(:node,"cluster_name:#{cluster_name}") do |n|
        @chef_nodes.push(n) unless n.nil? || (n.cluster_name != cluster_name.to_s)
      end
      @chef_nodes
    end

    # Walk the list of chef nodes and
    # * vivify the server,
    # * associate the chef node
    # * if the chef node knows about its instance id, memorize that for lookup
    #   when we discover cloud instances.
    def discover_chef_nodes!
      chef_nodes.each do |chef_node|
        cchef = chef_node.cluster_chef
        if cchef 
          cluster_name = cchef["cluster"]
          facet_name =  cchef["facet"]
          facet_index = cchef["index"]
        elsif chef_node["cluster_name"] && chef_node["facet_name"] && chef_node["facet_index"] 
          cluster_name = chef_node["cluster_name"] 
          facet_name = chef_node["facet_name"]  
          facet_index = chef_node["facet_index"] 
        else
          ( cluster_name, facet_name, facet_index ) = chef_node.node_name.split(/-/)
        end
        svr = ClusterChef::Server.get(cluster_name, facet_name, facet_index)
        svr.chef_node = chef_node
        @aws_instance_hash[ chef_node.ec2.instance_id ] = svr if chef_node[:ec2] && chef_node.ec2.instance_id
      end
    end

    # calling #servers vivifies each facet's ClusterChef::Server instances
    def discover_cluster_chef!
      self.servers
    end

    def discover_fog_servers!
      # If the fog server is tagged with cluster/facet/index, then try to
      # locate the corresponding machine in the cluster def
      # Otherwise, try to get to it through mapping the aws instance id
      # to the chef node name found in the chef node
      fog_servers.each do |fs|
        if fs.tags["cluster"] && fs.tags["facet"] && fs.tags["index"] && fs.tags["cluster"] == cluster_name.to_s
          svr = ClusterChef::Server.get(fs.tags["cluster"], fs.tags["facet"], fs.tags["index"])
        elsif @aws_instance_hash[fs.id]
          svr = @aws_instance_hash[fs.id]
        else
          next
        end

        # If there already is a fog server there, then issue a warning and slap
        # the just-discovered one onto a server with an arbitrary index, and
        # mark both bogus
        if existing_fs = svr.fog_server
          if existing_fs.id != fs.id
            warn "Duplicate fog instance found for #{svr.fullname}: #{fs.id} and #{existing_fs.id}!!"
            old_svr = svr
            svr     = old_svr.facet.server(1_000 + svr.facet_index.to_i)
            old_svr.bogosity :duplicate
            svr.bogosity     :duplicate
          end
        end
        svr.fog_server = fs
      end
    end

    def discover_volumes!
      servers.each(&:discover_volumes!)
    end

    def discover_addresses!
      servers.each(&:discover_addresses!)
    end
  end

  def self.connection
    @connection ||= Fog::Compute.new({
        :provider              => 'AWS',
        :aws_access_key_id     => Chef::Config[:knife][:aws_access_key_id],
        :aws_secret_access_key => Chef::Config[:knife][:aws_secret_access_key],
        #  :region                => region
      })
  end

  def self.fog_servers
    return @fog_servers if @fog_servers
    Chef::Log.debug("Using fog to catalog all servers")
    @fog_servers = ClusterChef.connection.servers.all
  end

  def self.fog_volumes
    return @fog_volumes if @fog_volumes
    Chef::Log.debug("Using fog to catalog all volumes")
    @fog_volumes ||= ClusterChef.connection.volumes
  end

  def self.fog_addresses
    return @fog_addresses if @fog_addresses
    Chef::Log.debug("Using fog to catalog all addresses")
    @fog_addresses = {}.tap{|hsh| ClusterChef.connection.addresses.each{|fa| hsh[fa.public_ip] = fa } }
  end

  def safely *args, &block
    ClusterChef.safely(*args, &block)
  end

end
