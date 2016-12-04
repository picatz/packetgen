require_relative 'spec_helper'

module PacketGen
  describe Capture do

    let(:iface) { PacketGen.default_iface }

    describe '#initialize' do
      it 'accepts no options' do
        cap = nil
        expect { cap = Capture.new(iface) }.to_not raise_error
        expect(cap).to be_a(Capture)
      end

      it 'accepts options' do
        options = { max: 12, timeout: 30, filter: 'ip', promisc: true, snaplen: 45 }
        expect { Capture.new(iface, options) }.to_not raise_error
      end
    end

    describe '#start' do
      it 'capture packets and returns a array of Packet', :sudo do
        cap = Capture.new('lo')
        cap_thread = Thread.new { cap.start }
        sleep 0.1
        system 'ping 127.0.0.1 -c 3 -i 0.2 > /dev/null'
        cap_thread.join(0.5)
        packets = cap.packets
        expect(packets).to be_a(Array)
        expect(packets.size).to eq(6)
        expect(packets.all? { |p| p.is_a? Packet }).to be(true)
        packets.each do |packet|
          expect(packet).to respond_to(:eth)
          expect(packet).to respond_to(:ip)
          expect(packet.ip.proto).to eq(1)
        end
      end

      it 'capture packets until :timeout seconds' do
        cap = Capture.new('lo')
        before = Time.now
        cap.start(timeout: 1)
        after = Time.now
        expect(after - before).to be < 2
      end

      it 'capture packets using a filter' do
        cap = Capture.new('lo', timeout: 1)
        cap_thread = Thread.new { cap.start(filter: 'ip dst 127.0.0.2') }
        sleep 0.1
        system '(ping -c 1 127.0.0.1; ping -c 1 127.0.0.2) > /dev/null'
        cap_thread.join(0.5)
        packets = cap.packets
        expect(packets.size).to eq(1)
        expect(packet.first.ip.src).to eq('127.0.0.1')
        expect(packet.first.ip.dst).to eq('127.0.0.2')
      end

      it 'capture packets and returns a array of string with :parse option to false' do
        cap = Capture.new('lo')
        cap_thread = Thread.new { cap.start(parse: false) }
        sleep 0.1
        system 'ping 127.0.0.1 -c 1 > /dev/null'
        cap_thread.join(0.5)
        packets = cap.packets
        expect(packets).to be_a(Array)
        expect(packets.size).to eq(2)
        expect(packets.all? { |p| p.is_a? String }).to be(true)
      end

      it 'capture :max packets' do
        cap = Capture.new('lo')
        cap_thread = Thread.new { cap.start(max: 2) }
        sleep 0.1
        system 'ping -c 2 -i 0.2 127.0.0.1 > /dev/null'
        cap_thread.join(0.5)
        packets = cap.packets
        expect(packets.size).to eq(2)
      end
    end
  end
end
