require 'json'
require 'zlib'
require 'sequel'
require_relative 'sha1'
require_relative 'signature'
require_relative 'sizedcache'

class Rational
	def to_json(*args)
		{n: numerator, d: denominator}.to_json(*args)
	end

	def self.from_json(attrs)
		Rational attrs['n'], attrs['d']
	end
end

module Blockchain
	InitialDifficulty = 10**40 * 5
	InitialReward = 64

	MagicHash = ''.sha1

	ChainDir = File.expand_path '../chain', __FILE__

	class << self
		def difficulty(time=Time.now)
			time = Time.at time if time.is_a? Numeric
			InitialDifficulty / 2**(time.year - 2014)
		end

		def reward(time=Time.now)
			time = Time.at time if time.is_a? Numeric
			InitialReward / 2**(time.year - 2014)
		end

		def each_block
			return to_enum :each_block unless block_given?
			chain.each do |id|
				yield Block[id]
			end
		end

		def chain
			@chain ||= load_chain
		end

		def [] index
			Block[chain[index]]
		end

		def []= index, block
			chain[index] = block.hash
			dump_chain
			block
		end

		private

		def dump_chain
			fn = File.join ChainDir, 'chain.dat'
			File.open fn, 'w' do |file|
				writer = Zlib::GzipWriter.new file
				writer.write JSON.dump chain
				writer.close
			end
		end

		def load_chain
			fn = File.join ChainDir, 'chain.dat'
			return [] unless File.exists? fn
			File.open fn do |file|
				reader = Zlib::GzipReader.new file
				chain = JSON.parse reader.read
				reader.close
				chain
			end
		end
	end

	class Transaction
		CoinbaseInputs = [[MagicHash, 0]]

		include Signable

		class << self
			def cached(input)
				return nil unless input.length == 2
				txn, which = input
				raw = cache_db[<<SQL, txn, which].first
SELECT target, amount_n, amount_d
	FROM outputs
	WHERE transaction_hash = ? AND
				which = ?;
SQL
				raw and [raw[:target], Rational(raw[:amount_n], raw[:amount_d])]
			end

			def cache(which, hash, output)
				return unless output.length == 2
				target, amount = output
				cols = hash, which, target, amount.numerator, amount.denominator
				raw = cache_db[<<SQL, *cols].first
INSERT
	INTO outputs
	VALUES (?, ?, ?, ?, ?);
SQL
			end

			def decache(input)
				return unless input.length == 2
				txn, which = input
				cache_db[<<SQL, txn, which].all
DELETE
	FROM outputs
	WHERE transaction_hash = ? AND
				which = ?;
SQL
			end

			private

			def cache_db
				return @cache_db if @cache_db
				Dir.mkdir ChainDir unless File.exists? ChainDir
				fn = File.join ChainDir, 'output_cache.sqlite'
				exists = File.exists? fn
				@cache_db = Sequel.sqlite fn
				unless exists
					@cache_db[<<SQL].all
CREATE TABLE outputs
	(transaction_hash text NOT NULL,
	 which int NOT NULL,
	 target text NOT NULL,
	 amount_n int NOT NULL,
	 amount_d int NOT NULL);
SQL
				end
				@cache_db
			end
		end

		attr_reader :inputs, :outputs, :timestamp

		def initialize(inputs, outputs, timestamp)
			@inputs, @outputs, @timestamp = inputs, outputs, timestamp
		end

		def cached_source(input)
			cached = Transaction.cached(input) and
				cached.first == pubkey.sha1 and
				cached
		end

		def valid?
			return false if not coinbase? and not signed?
			@valid ||= uncached_valid?
		end

		def conflicts?(txn)
			(@inputs & txn.inputs).any?
		end

		def coinbase?
			@coinbase ||= (@inputs == CoinbaseInputs and
				@outputs.one? and
				@outputs.first.last <= Blockchain.reward(@timestamp))
		end

		def hash
			@hash ||= (@inputs.map {|id, n| id + n.to_s}.inject('', :<<) <<
								 @outputs.map {|id, n| id + n.to_s}.inject('', :<<)).sha1
		end

		def apply
			@inputs.each do |input|
				Transaction.decache input
			end
			@outputs.each_with_index do |output, which|
				Transaction.cache which, hash, output
			end
		end

		def inspect
			"#<Transaction 0x#{hash}>"
		end

		def to_json(*args)
			{inputs: inputs, outputs: outputs,
		timestamp: timestamp, signature: signature}.to_json(*args)
		end

		def from_json(attrs)
			@inputs = attrs['inputs']
			@outputs = attrs['outputs'].map {|t, amt| [t, Rational.from_json(amt)]}
			@timestamp = attrs['timestamp']
			@signature = attrs['signature'] and Signature.from_json attrs['signature']
			self
		end

		def self.from_json(attrs)
			allocate.from_json(attrs)
		end

		private

		def uncached_valid?
			return true if coinbase?
			return false unless signed?
			source_amts = @inputs.map do |input|
				return false unless source = cached_source(input)
				source.last
			end
			@outputs.map(&:last).inject(:+) <= source_amts.inject(:+)
		end
	end

	class Block
		class << self
			def chain
				@chain ||= load_chain
			end

			def [] id
				block = block_cache[id]
				return block if block
				fn = File.join ChainDir, "block_#{id}.dat"
				return nil unless File.exists? fn
				File.open fn do |file|
					reader = Zlib::GzipReader.new file
					json = JSON.parse reader.read
					block = block_cache[id] = Block.from_json json
					reader.close
				end
				block
			end

			def []= id, block
				Dir.mkdir ChainDir unless File.exists? ChainDir
				fn = File.join ChainDir, "block_#{id}.dat"
				File.open fn, 'w' do |file|
					writer = Zlib::GzipWriter.new file
					writer.write JSON.dump block
					writer.close
				end
				block
			end

			private

			def block_cache
				@block_cache ||= SizedCache.new 20
			end
		end

		attr_reader :txns, :prev, :timestamp, :nonce

		def initialize(*args)
			raise ArgumentError unless args.length == 4
			@txns, @prev, @timestamp, @nonce = args
		end

		def hash
			@hash ||= (@nonce.to_s << prev <<
								 @timestamp.to_s <<
								 @txns.map(&:hash).inject('', :<<)).sha1
		end

		# gotta cache which blockchain is latest

		def index
			@index ||= uncached_index
		end

		def valid?
			unless @prev == MagicHash
				prev = Block[@prev]
				prev_ok = prev and prev.timestamp <= @timestamp
			else
				prev_ok = true
			end
			@valid ||= (prev_ok and
									@txns.all? {|txn| txn.timestamp <= @timestamp} and
									consistent? and
									@txns.all?(&:valid?) and
									@txns.count(&:coinbase?) < 2 and
									index == uncached_index)
		end

		def publishable?
			valid? and hash.hex <= Blockchain.difficulty(@timestamp)
		end

		def apply
			Block[hash] = self
			Blockchain[@index] = self
			@txns.each &:apply
		end

		def inspect
			"#<Block 0x#{hash}>"
		end

		def to_json(*args)
			{txns: txns, prev: prev,
		timestamp: timestamp,
		nonce: nonce, index: index}.to_json(*args)
		end

		def from_json(attrs)
			@txns = attrs['txns'].map {|txn| Transaction.from_json txn}
			@prev = attrs['prev']
			@timestamp = attrs['timestamp']
			@nonce = attrs['nonce']
			@index = attrs['index']
			self
		end

		def self.from_json(attrs)
			allocate.from_json(attrs)
		end

		private

		def consistent?
			@txns.each do |txn1|
				@txns.each do |txn2|
					next if txn1.equal? txn2
					return false if txn1.conflicts? txn2
				end
			end
			true
		end

		def uncached_index
			unless @prev == MagicHash
				prev = Block[@prev]
				prev and prev.index + 1
			else
				0
			end
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

