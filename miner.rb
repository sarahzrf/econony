require './blockchain'
pubkey = nil # put some way of acquiring the genesis miner's pubkey here
txn = Blockchain::Transaction.new [[BlockChain::MagicHash, 0]], [[pubkey.sha1, 64]], Time.now.to_i
nonce = 0
lowest = Float::INFINITY
genesis = Blockchain::Block.new([txn], Blockchain::MagicHash, Time.now, nonce)
until genesis.valid?
	if nonce > 4294967296
		nonce = 0
	else
		nonce += 1
	end
	genesis = Blockchain::Block.new([txn], Blockchain::MagicHash, Time.now.to_i, nonce)
	if genesis.hash.hex < lowest
		p lowest = genesis.hash.hex
	end
end
genesis.apply!

# vim:tabstop=2 shiftwidth=2 noexpandtab:

