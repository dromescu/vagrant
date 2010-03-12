module Vagrant
  class SSH
    class << self
      def connect(opts={})
        options = {}
        [:host, :username, :private_key_path].each do |param|
          options[param] = opts[param] || Vagrant.config.ssh.send(param)
        end

        Kernel.exec "ssh -p #{port(opts)} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i #{options[:private_key_path]} #{options[:username]}@#{options[:host]}".strip
      end

      def execute(opts={})
        Net::SSH.start(Vagrant.config.ssh.host, 
                       Vagrant.config[:ssh][:username], 
                       opts.merge( :port => port, 
                                   :keys => [Vagrant.config.ssh.private_key_path])) do |ssh|
          yield ssh
        end
      end

      def upload!(from, to)
        execute do |ssh|
          scp = Net::SCP.new(ssh)
          scp.upload!(from, to)
        end
      end

      def up?
        check_thread = Thread.new do
          begin
            Thread.current[:result] = false
            execute(:timeout => Vagrant.config.ssh.timeout) do |ssh|
              Thread.current[:result] = true
            end
          rescue Errno::ECONNREFUSED, Net::SSH::Disconnect
            # False, its defaulted above
          end
        end

        check_thread.join(Vagrant.config.ssh.timeout)
        return check_thread[:result]
      end

      def port(opts={})
        opts[:port] || Vagrant.config.vm.forwarded_ports[Vagrant.config.ssh.forwarded_port_key][:hostport]
      end
    end
  end
end
