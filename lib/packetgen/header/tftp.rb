# This file is part of PacketGen
# See https://github.com/sdaubert/packetgen for more informations
# Copyright (C) 2016 Sylvain Daubert <sylvain.daubert@laposte.net>
# This program is published under MIT license.

module PacketGen
  module Header

    # A TFTP (Trivial File Transfer Protocol,
    # {https://tools.ietf.org/html/rfc1350 RFC 1350}) header consists of:
    # * a {#opcode} ({Types::Int16Enum}),
    # * and a body. Its content depends on opcode.
    #
    # Specialized subclasses exists to handle {TFTP::Request Read/Write Request},
    # {TFTP::DATA DATA}, {TFTP::ACK ACK} and {TFTP::Error Error} packets.
    #
    # == Create a TFTP header
    #  # standalone
    #  tftp = PacketGen::Header::TFTP.new
    #  # in a packet
    #  pkt = PacketGen.gen('IP').add('UDP').add('TFTP')
    #  # access to TFTP header
    #  pkt.tftp   # => PacketGen::Header::TFTP
    #
    # == TFTP attributes
    #  tftp.opcode = 'RRQ'
    #  tftp.opcode = 1
    #  tftp.body.read 'this is a body'
    # @author Sylvain Daubert
    class TFTP < Base

      # Known opcodes
      OPCODES = {
        'RRQ'   => 1,
        'WRQ'   => 2,
        'DATA'  => 3,
        'ACK'   => 4,
        'Error' => 5
      }

      # @!attribute opcode
      #   16-bit operation code
      #   @return [Integer]
      define_field :opcode, Types::Int16Enum, enum: OPCODES
      
      # @!attribute body
      #   @return [String]
      define_field :body, Types::String
      
      def initialize(options={})
        type = protocol_name.sub(/^.*::/, '')
        opcode = OPCODES[type]
        if self.class != TFTP and !opcode.nil?
          super({opcode: opcode}.merge(options))
        else
          super
        end
      end

      # @private
      alias old_read read

      # Populate object from binary string
      # @param [String] str
      # @return [TFTP]
      def read(str)
        if self.instance_of? TFTP
          super
          if OPCODES.values.include? opcode
            TFTP.const_get(human_opcode).new.read str
          else
            self
          end
        else
          old_read str
        end
      end
      
      # Get human readable opcode
      # @return [String]
      def human_opcode
        self[:opcode].to_human
      end

      # Callback called when a TFTP header is added to a packet
      # Here, add +#tftp+ method as a shortcut to existing
      # +#tftp(rrq|wrq|data|ack|error)+.
      # @param [Packet] packet
      # @return [void]
      def added_to_packet(packet)
        unless packet.respond_to? :tftp
          packet.instance_eval("def tftp(arg=nil); header(#{self.class}, arg); end")
        end
      end

      # TFTP Read Request header
      class RRQ < TFTP
        delete_field :body
        undef body
        
        # @!attribute filename
        #   Filename to access
        #   @return [String]
        define_field :filename, Types::CString

        # @!attribute mode
        #   Mode used. Should be +netascii+, +octet+ or +mail+
        #   @return [String]
        define_field :mode, Types::CString
      end

      # TFTP Write Request header
      class WRQ < RRQ; end

      # TFTP DATA header
      class DATA < TFTP
        # @!attribute block_num
        #   16-bit block number
        #   @return [Integer]
        define_field_before :body, :block_num, Types::Int16
      end

      # TFTP ACK header
      class ACK < TFTP
        delete_field :body
        undef body
        
        # @!attribute block_num
        #   16-bit block number
        #   @return [Integer]
        define_field :block_num, Types::Int16
      end

      # TFTP ERROR header
      class ERROR < TFTP
        delete_field :body
        undef body

        # @!attribute error_code
        #   16-bit error code
        #   @return [Integer]
        define_field :error_code, Types::Int16

        # @!attribute error_msg
        #   Error message
        #   @return [String]
        define_field :error_msg, Types::CString
        alias error_message error_msg
      end
    end
    UDP.bind_header TFTP, dport: 69
  end
end
