require 'digest/sha1'

class String
	def sha1
		Digest::SHA1.hexdigest(self)
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

