require_relative 'blockchain'

class EcononyNode
	def req_main
		mailbox = ZMQ::Socket.new ZMQ::PULL
		mailbox.bind 'inproc://requests'
		requesters = []
		while true
			task, *args = mailbox.recv_array
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

