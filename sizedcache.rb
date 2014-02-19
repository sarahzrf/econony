require 'thread'

class SizedCache
	def initialize(size)
		@size = size
		@backing = {}
		@lock = Mutex.new
	end

	def [] key
		@backing[key]
	end

	def []= key, value
		@lock.synchronize do
			until @backing.size < @size
				@backing.delete @backing.keys.first
			end
			@backing[key] = value
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

