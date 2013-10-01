module Ebx
  class AwsRemote < AwsService

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
      app_location = '/var/app/current'
      execute_subprocess("cd #{app_location} && rails console")
    end

    def remote_shell
      execute_subprocess
    end

    private

    def execute(command)
      if !ec2_id
        puts "No active ec2 instances found in #{region}"
        return
      end

      `ssh ec2-user@#{dns_name} #{command}`
    end

    def execute_subprocess(command = "")
      puts command
      system "ssh ec2-user@#{dns_name} #{command}"
    end

    def ec2_id
      AwsEnvironment.new(region: region).ec2_instance_ids.first
    end

    def dns_name
      ec2.instances[ec2_id].dns_name
    end
  end
end
