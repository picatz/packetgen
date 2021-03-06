module PacketGen
  # Deprecation module
  # @since 2.7.0
  # @author Sylvain Daubert
  # @api private
  module Deprecation
    def self.deprecated(klass, deprecated_method, new_method=nil, klass_method: false, remove_version: '4.0.0')
      separator = klass_method ? '.' : '#'
      base_name = klass.to_s + separator
      complete_deprecated_method_name = base_name + deprecated_method.to_s
      complete_new_method_name = base_name + new_method.to_s unless new_method.nil?

      file, line = caller(2).first.split(':')[0, 2]
      message = +"#{file}:#{line}: #{complete_deprecated_method_name} is deprecated"
      message << "in favor of #{complete_new_method_name}" unless new_method.nil?
      message << ". It will be remove in PacketGen #{remove_version}."
      warn message
    end
  end
end
