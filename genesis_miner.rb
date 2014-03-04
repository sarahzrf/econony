require_relative 'blockchain'
print "Please enter the name of a file containing your private key: "
fn = gets.strip
print "Please enter your passphrase, if any: "
pp = gets.strip
pubkey = OpenSSL::PKey::RSA.new(File.read(fn), pp).public_key.to_s
coinbase = Blockchain::Transaction.new [[Blockchain::MagicHash, 0]], [[pubkey.sha1, 64.to_r]], Time.now.to_i
nonce = 0
lowest = Float::INFINITY
genesis = Blockchain::Block.new([coinbase], Blockchain::MagicHash, Time.now.to_i, nonce)
exit unless genesis.valid?
until genesis.publishable?
	if nonce > 4294967296
		nonce = 0
	else
		nonce += 1
	end
	genesis = Blockchain::Block.new([coinbase], Blockchain::MagicHash, Time.now.to_i, nonce)
	if genesis.hash.hex < lowest
		p lowest = genesis.hash.hex
	end
end
genesis.apply

# vim:tabstop=2 shiftwidth=2 noexpandtab:

