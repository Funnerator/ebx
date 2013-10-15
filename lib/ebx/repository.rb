module Ebx
  class Repository
    class << self

      def check_existance!
        if `git rev-parse --is-inside-work-tree`.chomp != 'true'
          raise "This command must be run from within a git repository"
        end
      end

      def check_committed!
        if `git status -s` != ""
          raise "Please commit all local changes before running this command"
        end
      end

      def check_pushed!
        check_existance!
        check_committed!
        fetch
        if `git rev-parse HEAD` != `git rev-parse @{u}`
          raise 'The local and origin repos are not the same. Please push before running this command.'
        end
      end

      def branch
        `git rev-parse --abbrev-ref HEAD`
      end

      def fetch
        `git fetch`
      end

      def deployment_tags
        `git tag`.split.select {|t| t.match /V\d+/ }.sort {|a, b| a[1..-1].to_i <=> b[1..-1].to_i }
      end

      def next_deployment_tag
        "V#{deployment_tags.last[1..-1].to_i + 1}"
      end

      def tag_deployment
        tag = next_deployment_tag
        `git tag -a #{tag} -m "Deploy"`
        `git push origin #{tag}`
      end
    end
  end
end
