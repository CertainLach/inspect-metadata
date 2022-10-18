import { Call, writeCall } from './lookup';

/// Decided by 20 NAT255 dice rolls
const randomEthAddress = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x11, 0x22, 0x33, 0x44, 0x55] as const;

const transfer: Call = {
    Unique: {
        transfer_from: {
            collection_id: 10,
            from: { Ethereum: randomEthAddress },
            item_id: 1,
            recipient: { Ethereum: randomEthAddress },
            value: 200000000000000000000n,
        }
    }
};
const sudoTransfer: Call = {
    Sudo: {
        sudo_as: {
            who: {
                Address20: randomEthAddress,
            },
            call: transfer
        }
    }
};
const buf = [];
writeCall(buf, sudoTransfer);
console.log(buf.map(d => d.toString(16).padStart(2, '0')).join(''))
