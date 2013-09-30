module Ebx
  module PrettyPrint
    def colorize(str)
      case str
      when 'Red', 'ERROR', 'FATAL'
        str.color(:red)
      when 'WARN'
        str.color(:yellow)
      when 'Ready', 'Green', 'INFO'
        str.color(:green)
      else
        str.color(:white)
      end
    end
  end
end
