module Ebx
  class AwsRemote < AwsService
    APP_LOCATION = '/var/app/current'

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
      puts region
      if running?
        puts command
        `ssh ec2-user@#{dns_name} #{command}`
      else
        puts "No active ec2 instances found in #{region}"
      end
    end

    def execute_subprocess(command = "")
      puts region
      if running?
        puts command
        system "ssh ec2-user@#{dns_name} #{command}"
      else
        puts "No active ec2 instances found in #{region}"
      end
    end

    def running?
      !AwsEnvironment.find_running(region).empty?
    end

    def ec2_id
      AwsEnvironment.find_running(region).first.ec2_instance_ids.first
    end

    def dns_name
      ec2.instances[ec2_id].dns_name
    end
  end
end
