module Ebx
  class AwsRemote < AwsService
    APP_LOCATION = '/var/app/current'
    attr_reader :all_machines

    def initialize(options = {})
      super(options)
      @all_machines = !!options[:all_machines]
    end

    def logs(follow = false)
      logs = "/var/log/eb* /var/log/cfn*"
      # /var/app/support/logs/* 
      if follow
        execute_subprocess("tail -f -n 0 #{logs}")
      else
        execute("tail #{logs}")
      end
    end

    def console
      execute_subprocess("cd #{APP_LOCATION} && rails console")
    end

    def remote_shell
      execute_subprocess
    end

    def rake(cmd)
      execute("cd #{APP_LOCATION} && rake #{cmd}")
    end

    private

    def execute(command)
      setup_command do |dns_name|
        `ssh ec2-user@#{dns_name} #{command}`
      end
    end

    def execute_subprocess(command = "")
      setup_command do |dns_name|
        system "ssh ec2-user@#{dns_name} #{command}"
      end
    end

    def running?
      !AwsEnvironment.find_running(region).empty?
    end

    def leader_ec2_id
      AwsEnvironment.find_running(region).first.ec2_instance_ids.first
    end

    def leader_dns_name
      ec2.instances[leader_ec2_id].dns_name
    end

    def dns_names
      ec2.instances.map(&:dns_name)
    end

    private

    def setup_command(&block)
      puts region
      if running?
        dnames = all_machines ? [leader_dns_name] : dns_names
        puts command
        dnames.each { |n| yield(n) }
      else
        puts "No active ec2 instances found in #{region}"
      end
    end
  end
end
