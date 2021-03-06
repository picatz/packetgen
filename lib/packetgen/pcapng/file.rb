# This file is part of PacketGen
# See https://github.com/sdaubert/packetgen for more informations
# Copyright (C) 2016 Sylvain Daubert <sylvain.daubert@laposte.net>
# This program is published under MIT license.

# frozen_string_literal: true

module PacketGen
  module PcapNG
    # PcapNG::File is a complete Pcap-NG file handler.
    # @author Sylvain Daubert
    class File
      # Known link types
      KNOWN_LINK_TYPES = {
        LINKTYPE_ETHERNET => 'Eth',
        LINKTYPE_IEEE802_11 => 'Dot11',
        LINKTYPE_IEEE802_11_RADIOTAP => 'RadioTap',
        LINKTYPE_PPI => 'PPI',
        LINKTYPE_IPV4 => 'IP',
        LINKTYPE_IPV6 => 'IPv6'
      }.freeze

      # Get file sections
      # @return [Array]
      attr_accessor :sections

      def initialize
        @sections = []
      end

      # Read a string to populate the object. Note that this appends new blocks to
      # the Pcapng::File object.
      # @param [String] str
      # @return [self]
      def read(str)
        PacketGen.force_binary(str)
        io = StringIO.new(str)
        parse_section(io)
        self
      end

      # Clear the contents of the Pcapng::File prior to reading in a new string.
      # This string should contain a Section Header Block and an Interface Description
      # Block to create a conform pcapng file.
      # @param [String] str
      # @return [self]
      def read!(str)
        clear
        read(str)
      end

      # Read a given file and analyze it.
      # If given a block, it will yield PcapNG::EPB or PcapNG::SPB objects.
      # This is the only way to get packet timestamps.
      # @param [String] fname pcapng file name
      # @yieldparam [EPB,SPB] block
      # @return [Integer] return number of yielded blocks (only if a block is given)
      # @raise [ArgumentError] cannot read +fname+
      def readfile(fname, &blk)
        unless ::File.readable?(fname)
          raise ArgumentError, "cannot read file #{fname}"
        end

        ::File.open(fname, 'rb') do |f|
          parse_section(f) until f.eof?
        end

        return unless blk

        count = 0
        @sections.each do |section|
          section.interfaces.each do |intf|
            intf.packets.each do |pkt|
              count += 1
              yield pkt
            end
          end
        end
        count
      end

      # Give an array of raw packets (raw data from packets).
      # If a block is given, yield raw packet data from the given file.
      # @overload read_packet_bytes(fname)
      #  @param [String] fname pcapng file name
      #  @return [Array] array of packet raw data
      # @overload read_packet_bytes(fname)
      #  @param [String] fname pcapng file name
      #  @yieldparam [String] raw packet raw data
      #  @yieldparam [Integer] interface's link_type from which packet was captured
      #  @return [Integer] number of packets
      # @raise [ArgumentError] cannot read +fname+
      def read_packet_bytes(fname, &blk)
        count = 0
        packets = [] unless blk

        readfile(fname) do |packet|
          if blk
            count += 1
            yield packet.data.to_s, packet.interface.link_type
          else
            packets << packet.data.to_s
          end
        end

        blk ? count : packets
      end

      # Return an array of parsed packets.
      # If a block is given, yield parsed packets from the given file.
      # @overload read_packets(fname)
      #  @param [String] fname pcapng file name
      #  @return [Array<Packet>]
      # @overload read_packets(fname)
      #  @param [String] fname pcapng file name
      #  @yieldparam [Packet] packet
      #  @return [Integer] number of packets
      # @raise [ArgumentError] cannot read +fname+
      def read_packets(fname, &blk)
        count = 0
        packets = [] unless blk

        read_packet_bytes(fname) do |packet, link_type|
          first_header = KNOWN_LINK_TYPES[link_type]
          parsed_pkt = if first_header.nil?
                         # unknown link type, try to guess
                         Packet.parse(packet)
                       else
                         Packet.parse(packet, first_header: first_header)
                       end
          if blk
            count += 1
            yield parsed_pkt
          else
            packets << parsed_pkt
          end
        end

        blk ? count : packets
      end

      # Return the object as a String
      # @return [String]
      def to_s
        @sections.map(&:to_s).join
      end

      # Clear the contents of the Pcapng::File.
      # @return [void]
      def clear
        @sections.clear
      end

      # Translates a {File} into an array of packets.
      # @param [Hash] options
      # @option options [String] :filename if given, object is cleared and filename
      #   is analyzed before generating array. Else, array is generated from +self+
      # @option options [String] :file same as +:filename+
      # @option options [Boolean] :keep_timestamps if +true+ (default value: +false+),
      #   generates an array of hashes, each one with timestamp as key and packet
      #   as value. There is one hash per packet.
      # @option options [Boolean] :keep_ts same as +:keep_timestamp+
      # @return [Array<Packet>,Array<Hash>]
      def file_to_array(options={})
        filename = options[:filename] || options[:file]
        if filename
          clear
          readfile filename
        end

        ary = []
        @sections.each do |section|
          section.interfaces.each do |itf|
            if options[:keep_timestamps] || options[:keep_ts]
              ary.concat(itf.packets.map { |pkt| { pkt.timestamp => pkt.data.to_s } })
            else
              ary.concat(itf.packets.map { |pkt| pkt.data.to_s })
            end
          end
        end
        ary
      end

      # Writes the {File} to a file.
      # @param [Hash] options
      # @option options [Boolean] :append (default: +false+) if set to +true+,
      #   the packets are appended to the file, rather than overwriting it
      # @return [Array] array of 2 elements: filename and size written
      def to_file(filename, options={})
        mode = if options[:append] && ::File.exist?(filename)
                 'ab'
               else
                 'wb'
               end
        ::File.open(filename, mode) { |f| f.write(self.to_s) }
        [filename, self.to_s.size]
      end
      alias to_f to_file

      # Shorthand method for writing to a file.
      # @param [#to_s] filename
      # @return [Array] see return value from {#to_file}
      def write(filename='out.pcapng')
        self.to_file(filename.to_s, append: false)
      end

      # Shorthand method for appending to a file.
      # @param [#to_s] filename
      # @return [Array] see return value from {#to_file}
      def append(filename='out.pcapng')
        self.to_file(filename.to_s, append: true)
      end

      # @overload array_to_file(ary)
      #  Update {File} object with packets.
      #  @param [Array] ary as generated by {#file_to_array} or Array of Packet objects.
      #                 Update {File} object without writing file on disk
      #  @return [self]
      # @overload array_to_file(options={})
      #  Update {File} and/or write it to a file
      #  @param [Hash] options
      #  @option options [String] :filename file written on disk only if given
      #  @option options [Array] :array can either be an array of packet data,
      #                                 or a hash-value pair of timestamp => data.
      #  @option options [Time] :timestamp set an initial timestamp
      #  @option options [Integer] :ts_inc set the increment between timestamps.
      #                                    Defaults to 1
      #  @option options [Boolean] :append if +true+, append packets to the end of
      #                                    the file
      #  @return [Array] see return value from {#to_file}
      def array_to_file(options={})
        case options
        when Hash
          filename = options[:filename] || options[:file]
          ary = options[:array] || options[:arr]
          unless ary.is_a? Array
            raise ArgumentError, ':array parameter needs to be an array'
          end
          ts = options[:timestamp] || options[:ts] || Time.now
          ts_inc = options[:ts_inc] || 1
          append = !options[:append].nil?
        when Array
          ary = options
          ts = Time.now
          ts_inc = 1
          filename = nil
          append = false
        else
          raise ArgumentError, 'unknown argument. Need either a Hash or Array'
        end

        section = SHB.new
        @sections << section
        itf = IDB.new(endian: section.endian)
        classify_block section, itf

        ary.each_with_index do |pkt, i|
          case pkt
          when Hash
            this_ts = pkt.keys.first.to_i
            this_cap_len = pkt.values.first.to_s.size
            this_data = pkt.values.first.to_s
          else
            this_ts = (ts + ts_inc * i).to_i
            this_cap_len = pkt.to_s.size
            this_data = pkt.to_s
          end
          this_ts = (this_ts / itf.ts_resol).to_i
          this_tsh = this_ts >> 32
          this_tsl = this_ts & 0xffffffff
          this_pkt = EPB.new(endian:       section.endian,
                             interface_id: 0,
                             tsh:          this_tsh,
                             tsl:          this_tsl,
                             cap_len:      this_cap_len,
                             orig_len:     this_cap_len,
                             data:         this_data)
          classify_block section, this_pkt
        end

        if filename
          self.to_f(filename, append: append)
        else
          self
        end
      end

      private

      # Parse a section. A section is made of at least a SHB. It than may contain
      # others blocks, such as  IDB, SPB or EPB.
      # @param [IO] io
      # @return [void]
      def parse_section(io)
        shb = SHB.new
        type = Types::Int32.new(0, shb.endian).read(io.read(4))
        io.seek(-4, IO::SEEK_CUR)
        shb = parse(type, io, shb)
        raise InvalidFileError, 'no Section header found' unless shb.is_a?(SHB)

        if shb.section_len.to_i != 0xffffffffffffffff
          # Section length is defined
          section = StringIO.new(io.read(shb.section_len.to_i))
          until section.eof?
            shb = @sections.last
            type = Types::Int32.new(0, shb.endian).read(section.read(4))
            section.seek(-4, IO::SEEK_CUR)
            parse(type, section, shb)
          end
        else
          # section length is undefined
          until io.eof?
            shb = @sections.last
            type = Types::Int32.new(0, shb.endian).read(io.read(4))
            io.seek(-4, IO::SEEK_CUR)
            parse(type, io, shb)
          end
        end
      end

      # Parse a block from its type
      # @param [Types::Int32] type
      # @param [IO] io stream from which parse block
      # @param [SHB] shb header of current section
      # @return [void]
      def parse(type, io, shb)
        types = PcapNG.constants(false).select { |c| c.to_s =~ /_TYPE/ }
                      .map { |c| [PcapNG.const_get(c).to_i, c] }
        types = Hash[types]

        if types.key?(type.to_i)
          klass = PcapNG.const_get(types[type.to_i].to_s.gsub(/_TYPE/, '').to_sym)
          block = klass.new(endian: shb.endian)
        else
          block = UnknownBlock.new(endian: shb.endian)
        end

        classify_block shb, block
        block.read(io)
      end

      # Classify block from its type
      # @param [SHB] shb header of current section
      # @param [Block] block block to classify
      # @return [void]
      def classify_block(shb, block)
        case block
        when SHB
          @sections << block
        when IDB
          shb << block
          block.section = shb
        when EPB
          shb.interfaces[block.interface_id] << block
          block.interface = shb.interfaces[block.interface_id]
        when SPB
          shb.interfaces[0] << block
          block.interface = shb.interfaces[0]
        else
          shb.unknown_blocks << block
          block.section = shb
        end
      end
    end
  end
end
