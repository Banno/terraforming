module Terraforming
  module Resource
    class EC2
      include Terraforming::Util

      def self.tf(client: Aws::EC2::Client.new)
        self.new(client).tf
      end

      def self.tfstate(client: Aws::EC2::Client.new, tfstate_base: nil)
        self.new(client).tfstate(tfstate_base)
      end

      def initialize(client)
        @client = client
      end

      def tf
        apply_template(@client, "tf/ec2")
      end

      def tfstate(tfstate_base)
        resources = instances.inject({}) do |result, instance|
          in_vpc = in_vpc?(instance)

          attributes = {
            "ami"=> instance.image_id,
            "associate_public_ip_address"=> "true",
            "availability_zone"=> instance.placement.availability_zone,
            "ebs_block_device.#"=> instance.block_device_mappings.length.to_s,
            "ebs_optimized"=> instance.ebs_optimized.to_s,
            "ephemeral_block_device.#"=> "0",
            "id"=> instance.instance_id,
            "instance_type"=> instance.instance_type,
            "private_dns"=> instance.private_dns_name,
            "private_ip"=> instance.private_ip_address,
            "public_dns"=> instance.public_dns_name,
            "public_ip"=> instance.public_ip_address,
            "root_block_device.#"=> instance.root_device_name ? "1" : "0",
            "security_groups.#"=> in_vpc ? "0" : instance.security_groups.length.to_s,
            "source_dest_check"=> instance.source_dest_check.to_s,
            "tenancy"=> instance.placement.tenancy,
            "vpc_security_group_ids.#"=> in_vpc ? instance.security_groups.length.to_s : "0",
          }

          attributes["subnet_id"] = instance.subnet_id if in_vpc?(instance)

          result["aws_instance.#{module_name_of(instance)}"] = {
            "type" => "aws_instance",
            "primary" => {
              "id" => instance.instance_id,
              "attributes" => attributes,
              "meta" => {
                "schema_version" => "1"
              }
            }
          }

          result
        end

        generate_tfstate(resources, tfstate_base)
      end

      private

      #
      # NOTE(dtan4):
      #   Original logic is here:
      #     https://github.com/hashicorp/terraform/blob/281e4d3e67f66daab9cdb1f7c8b6f602d949e5ee/builtin/providers/aws/resource_aws_instance.go#L481-L501
      #
      def in_vpc?(instance)
        vpc_security_groups_of(instance).length > 0 ||
          (instance.subnet_id && instance.subnet_id != "" && instance.security_groups.length == 0)
      end

      def instances
        @client.describe_instances.reservations.map(&:instances).flatten
      end

      def module_name_of(instance)
        normalize_module_name(name_from_tag(instance, instance.instance_id))
      end

      def vpc_security_groups_of(instance)
        instance.security_groups.select { |security_group| /\Asg-/ =~ security_group.group_id }
      end
    end
  end
end
