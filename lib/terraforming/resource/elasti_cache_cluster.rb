module Terraforming
  module Resource
    class ElastiCacheCluster
      include Terraforming::Util

      def self.tf(client: Aws::ElastiCache::Client.new)
        self.new(client).tf
      end

      def self.tfstate(client: Aws::ElastiCache::Client.new, tfstate_base: nil)
        self.new(client).tfstate(tfstate_base)
      end

      def initialize(client)
        @client = client
      end

      def tf
        apply_template(@client, "tf/elasti_cache_cluster")
      end

      def tfstate(tfstate_base)
        resources = cache_clusters.inject({}) do |result, cache_cluster|
          attributes = {
            "cache_nodes.#" => cache_cluster.cache_nodes.length.to_s,
            "cluster_id" => cache_cluster.cache_cluster_id,
            "engine" => cache_cluster.engine,
            "engine_version" => cache_cluster.engine_version,
            "id" => cache_cluster.cache_cluster_id,
            "node_type" => cache_cluster.cache_node_type,
            "num_cache_nodes" => "1",
            "parameter_group_name" => cache_cluster.cache_parameter_group.cache_parameter_group_name,
            "port" => "11211",
            "security_group_ids.#" => security_group_ids_of(cache_cluster).length.to_s,
            "security_group_names.#" => security_group_names_of(cache_cluster).length.to_s,
            "subnet_group_name" => cache_cluster.cache_subnet_group_name,
            "tags.#" => "0",
          }
          result["aws_elasticache_cluster.#{cache_cluster.cache_cluster_id}"] = {
            "type" => "aws_elasticache_cluster",
            "primary" => {
              "id" => cache_cluster.cache_cluster_id,
              "attributes" => attributes
            }
          }

          result
        end

        generate_tfstate(resources, tfstate_base)
      end

      private

      def cache_clusters
        @client.describe_cache_clusters(show_cache_node_info: true).cache_clusters
      end

      def cluster_in_vpc?(cache_cluster)
        cache_cluster.cache_security_groups.length == 0
      end

      def security_group_ids_of(cache_cluster)
        cache_cluster.security_groups.map { |sg| sg.security_group_id }
      end

      def security_group_names_of(cache_cluster)
        cache_cluster.cache_security_groups.map { |sg| sg.cache_security_group_name }
      end
    end
  end
end
