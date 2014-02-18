require 'pry'
require './blockchain'
lowest = Float::INFINITY
nonce = 0
empty = ''.sha1
b = Blockchain::Block.new([], empty, Time.now, nonce)
until b.valid?
	if nonce > 4294967296
		nonce = 0
	else
		nonce += 1
	end
	b = Blockchain::Block.new([], empty, Time.now, nonce)
	if b.hash < lowest
		p lowest = b.hash
		#binding.pry
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

