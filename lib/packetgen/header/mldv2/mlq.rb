# This file is part of PacketGen
# See https://github.com/sdaubert/packetgen for more informations
# Copyright (C) 2016 Sylvain Daubert <sylvain.daubert@laposte.net>
# This program is published under MIT license.

# frozen_string_literal: true

module PacketGen
  module Header
    module MLDv2
      # This class supports MLDv2 Multicast Listener Query messages.
      #
      # From RFC 3810, a MLDv2 Multicast Listener Query message has the
      # following format:
      #                      1                   2                   3
      #  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      #  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      #  |  Type = 130   |      Code     |           Checksum            |
      #  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      #  |    Maximum Response Code      |           Reserved            |
      #  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      #  |                                                               |
      #  *                                                               *
      #  |                                                               |
      #  *                       Multicast Address                       *
      #  |                                                               |
      #  *                                                               *
      #  |                                                               |
      #  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      #  | Resv  |S| QRV |     QQIC      |     Number of Sources (N)     |
      #  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      #  |                                                               |
      #  *                                                               *
      #  |                                                               |
      #  *                       Source Address [1]                      *
      #  |                                                               |
      #  *                                                               *
      #  |                                                               |
      #  +-                                                             -+
      #  |                                                               |
      #  *                                                               *
      #  |                                                               |
      #  *                       Source Address [2]                      *
      #  |                                                               |
      #  *                                                               *
      #  |                                                               |
      #  +-                              .                              -+
      #  .                               .                               .
      #  .                               .                               .
      #  +-                                                             -+
      #  |                                                               |
      #  *                                                               *
      #  |                                                               |
      #  *                       Source Address [N]                      *
      #  |                                                               |
      #  *                                                               *
      #  |                                                               |
      #  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      # +type+, +code+ and +checksum+ are fields from {ICMPv6} header.
      #
      # MLQ fields are:
      # * {#max_resp_code #max_resp_code} ({Types::Int16}),
      # * {#reserved #reserved} ({Types::Int16}),
      # * {#mcast_addr #mcast_addr} ({IPv6::Addr}),
      # * {#flags} ({Types::Int8}), with sub-fields:
      #   * a 4-bit {#flag_resv} field,
      #   * a 1-bit {#flag_s} boolean,
      #   * a 3-bit {#flag_qrv} field,
      # * {#qqic} ({Types::Int8}),
      # * {#number_of_sources} ({Types::Int16}),
      # * and {#source_addr}, a {IPv6::ArrayOfAddr}.
      #
      # == Max Resp Delay
      # Max Resp Delay is the real delay value. Max Resp Code is the encoded
      # delay. So {#max_resp_delay} and {#max_resp_code} attributes reflect this
      # difference.
      # @author Sylvain Daubert
      class MLQ < MLD
        # @!attribute flags
        #  8-bit flags
        #  @return [Integer]
        define_field_before :body, :flags, Types::Int8
        # @!attribute qqic
        #  8-bit QQIC
        #  @return [Integer]
        define_field_before :body, :qqic, Types::Int8
        # @!attribute number_of_sources
        #  16-bit number of sources
        #  @return [Integer]
        define_field_before :body, :number_of_sources, Types::Int16
        # @!attribute source_addr
        #  Array of IPv6 source addresses
        #  @return [IPv6::ArrayOfAddr]
        define_field_before :body, :source_addr, IPv6::ArrayOfAddr,
                            builder: ->(h,t) { t.new(counter: h[:number_of_sources]) }

        # @!attribute flag_resv
        #   4-bit reserved field in {#flags}
        #   @return [Integer]
        # @!attribute flag_s
        #   S Flag (Suppress Router-Side Processing)
        #   @return [Boolean]
        # @!attribute flag_qrv
        #   3-bit QRV (Querier's Robustness Variable)
        #   @return [Integer]
        define_bit_fields_on :flags, :flag_resv, 4, :flag_s, :flag_qrv, 3

        # Getter for +max_resp_code+ for MLDv2 packets. Use {MLDv2.decode}.
        # @return [Integer]
        # @note May return a different value from value previously set, as a
        #   float encoding is used to encode big values. See {MLDv2.decode}.
        def max_resp_delay
          MLDv2.decode(self[:max_resp_delay].to_i)
        end

        # Setter for +max_resp_code+ for MLDv2 packets. Use {MLDv2.encode}.
        # @param [Integer] value
        # @return [Integer]
        # @note See {MLDv2.encode}.
        def max_resp_delay=(value)
          self[:max_resp_delay].value = MLDv2.encode(value)
        end

        # Get QQIC value
        # @note May return a different value from value previously set, as a
        #   float encoding is used to encode big values. See {IGMPv3.decode}.
        # @return [Integer]
        def qqic
          IGMPv3.decode self[:qqic].to_i
        end

        # Set QQIC value
        # @note See {IGMPv3.encode}.
        # @param [Integer] value
        # @return [Integer]
        def qqic=(value)
          self[:qqic].value = IGMPv3.encode(value)
        end
      end
    end
    
    self.add_class MLDv2::MLQ
    ICMPv6.bind_header MLDv2::MLQ, op: :and, type: 130, body: ->(b) { b.nil? ? '' : b.length > 23 }

  end
end
