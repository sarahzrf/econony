require 'date'
require 'sequel'
require_relative 'sha1'
require_relative 'signature'

# the blockchain will be stored as a hash
# of id => block, probably backed by the FS

module Blockchain
	InitialDifficulty = 10**40 * 5
	Difficulty = InitialDifficulty / 2**(Time.now.year - 2014)
	InitialReward = 64

	MagicHash = ''.sha1

	ChainDir = File.expand_path '../chain', __FILE__

	module_function

	def reward_at(time)
		time = Time.at time if time.is_a? Numeric
		InitialReward / 2**(time.year - 2014)
	end

	def each_block
		return to_enum :each_block unless block_given?
		return unless File.exists? ChainDir
		Dir.entries(ChainDir).each do |fn|
			fn =~ /block_(\w+)\.dat/
			next unless $1
			yield Block[$1]
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
SELECT target, amount
  FROM outputs
  WHERE transaction_hash = ? AND
        which = ?;
SQL
				raw and [raw[:target], raw[:amount]]
			end

			def cache(which, hash, output)
				return unless output.length == 2
				target, amount = output
				raw = cache_db[<<SQL, hash, which, target, amount].first
INSERT
  INTO outputs
	VALUES (?, ?, ?, ?);
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
				fn = File.join(ChainDir, 'output_cache.sqlite')
				exists = File.exists? fn
				@cache_db = Sequel.sqlite fn
				unless exists
					@cache_db[<<SQL].all
CREATE TABLE outputs
  (transaction_hash text NOT NULL,
   which int NOT NULL,
   target text NOT NULL,
   amount float NOT NULL);
SQL
				end
				@cache_db
			end
		end

		attr_reader :inputs, :outputs, :timestamp

		def initialize(*args)
			raise ArgumentError unless args.length == 3
			@inputs, @outputs, @timestamp = args
		end

		def can_source?(input)
			cached = Transaction.cached(input) and
				cached.first == pubkey.sha1 and
				cached
		end

		def valid?
			@valid ||= uncached_valid?
		end

		def conflicts?(txn)
			(@inputs & txn.inputs).any?
		end

		def coinbase?
			@coinbase ||= @inputs == CoinbaseInputs and
				@outputs.one? and
				@outputs.first.last <= Blockchain.reward_at(@timestamp)
		end

		def hash
			@hash ||= (@inputs.map {|id, n| id + n.to_s}.inject('', :<<) <<
								 @outputs.map {|id, n| id + n.to_s}.inject('', :<<)).sha1
		end

		def apply!
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

		private

		def uncached_valid?
			return true if coinbase?
			return false unless signed?
			source_amts = @inputs.map do |input|
				return false unless source = can_source?(input)
				source.last
			end
			@outputs.map(&:last).inject(:+) <= source_amts.inject(:+)
		end
	end

	class Block
		def self.[] id
			fn = File.join ChainDir, "block_#{id}.dat"
			return nil unless File.exists? fn
			File.open fn do |file|
				Marshal.load file
			end
		end

		def self.[]= id, block
			Dir.mkdir ChainDir unless File.exists? ChainDir
			fn = File.join ChainDir, "block_#{id}.dat"
			File.open fn, 'w' do |file|
				file.write Marshal.dump block
			end
		end

		attr_reader :txns, :prev, :timestamp, :nonce

		def initialize(*args)
			raise ArgumentError unless args.length == 4
			@txns, @prev, @timestamp, @nonce = args
		end

		def hash
			@hash ||= (@nonce.to_s << prev.to_s <<
								 @timestamp.to_s <<
								 @txns.map(&:hash).inject('', :<<)).sha1
		end

		def valid?
			unless @prev == MagicHash
				prev = Block[@prev]
				prev_ok = prev and prev.timestamp < @timestamp
			else
				prev_ok = true
			end
			@valid ||= prev_ok and
				@txns.all? {|txn| txn.timestamp < @timestamp} and
				consistent? and
				@txns.all?(&:valid?) and
				@txns.count(&:coinbase?) < 2
		end

		def publishable?
			valid? and hash.hex < Blockchain::Difficulty
		end

		def apply!
			Block[hash] = self
			@txns.each &:apply!
		end

		def inspect
			"#<Block 0x#{hash}>"
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
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

