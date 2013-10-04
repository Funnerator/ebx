module Ebx
  class Route53

    def update_cnames(environments)
      environments.each do |env|
        Ebx.set_region(env.region) # needs to be set for settings

        create_hosted_zone if !hosted_zone

        record = find_record_for_ebx_env(env)
        if !record
          create_record_for_env(env)
        elsif record[:cname] != env.cname
          update_record_for_env(record, env)
        end
      end
    end

    def hosted_zones
      @hosted_zones ||= begin
        AWS.route_53.client.list_hosted_zones[:hosted_zones]
      end
    end

    def create_hosted_zone
      response = AWS.route_53.create_hosted_zone(
        name: Settings.get(:domain),
        caller_reference: "ebx_dns_migration_#{Settings.get(:domain)}",
        hosted_zone_config: {
          comment: 'Hosted zone autocreated by ebx'
        }
      )
      @hosted_zones = nil
      response[:hosted_zone]
    end

    def hosted_zone
      hosted_zones.find {|z| z[:name] == "#{Settings.get(:domain)}." }
    end

    def resource_record_sets
      @resource_record_sets ||= begin
        AWS.route_53.client.list_resource_record_sets(
          hosted_zone_id: hosted_zone[:id],
          start_record_name: domain_name,
          start_record_type: "CNAME"
        )[:resource_record_sets]
      end
    end

    def find_record_for_ebx_env(env)
      resource_record_sets.find {|r| r[:region] == env.region && r[:set_identifier] =~ /#{Ebx.env}/ }
    end

    def find_record_for_region(region)
      resource_record_sets.find {|r| r[:region] == region }
    end

    def domain_name
      "#{Settings.get(:subdomain)}.#{Settings.get(:domain)}"
    end

    def update_record_for_env(record, env)
      changes = [{
          action: 'DELETE',
          resource_record_set: record
        }]
      puts "deleting CNAME for #{record[:name]} in #{env.region}"
      create_record_for_env(env, changes)
    end

    def create_record_for_env(env, changes = [])
      changes << {
        action: 'CREATE',
        resource_record_set: {
          name: domain_name,
          type: 'CNAME',
          ttl: 300,
          set_identifier: "#{Ebx.env}-#{env.region} datacenter",
          region: env.region,
          resource_records: [{
            value: env.cname
          }]
        }
      }

      @resource_record_sets = nil
      puts "creating CNAME for #{domain_name} in #{env.region}"
      AWS.route_53.client.change_resource_record_sets(
        hosted_zone_id: hosted_zone[:id],
        change_batch: {
          changes: changes
        }
      )
    end

    def cname_for_record(record)
      record[:resource_records].first[:value]
    end
  end
end
