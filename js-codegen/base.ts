export const I_AM_A_MODULE = '';
export const ENCODER = new TextEncoder();

/**
 * Base definitions, hand-written
 */

type FixedSizeArray<
    T,
    N extends number,
    R extends readonly T[] = [],
    > = R['length'] extends N ? R : FixedSizeArray<T, N, readonly [T, ...R]>;

// TODO: Implement using Uint8Array
type Buf = number[]
function newBuf(): Buf {
    return [];
}
function putBytes(out: Buf, bytes: readonly number[]) {
    for (let byte of bytes) {
        if (byte < 0 || byte > 255) throw new Error('byte out of range');
    }
    out.push(...bytes);
}

type Primitive_bool = boolean;
const writePrimitive_bool = (out: Buf, value: Primitive_bool) => putBytes(out, [value && 1 || 0]);

type Primitive_u8 = number;
const writePrimitive_u8 = (out: Buf, value: Primitive_u8) => {
    if (value < 0 || value > 255) throw new Error('u8 out of range');
    putBytes(out, [value])
};

type Primitive_u16 = number;
const writePrimitive_u16 = (out: Buf, value: Primitive_u16) => {
    if (value < 0 || value > 0xffff) throw new Error('u16 out of range');
    putBytes(out, [value & 0xff, (value & 0xff00) >> 8]);
}
type Primitive_u32 = number;
const writePrimitive_u32 = (out: Buf, value: Primitive_u32) => {
    if (value < 0 || value > 0xffffffff) throw new Error('u32 out of range');
    putBytes(out, [value & 0xff, (value & 0xff00) >> 8, (value & 0xff0000) >> 16, (value & 0xff000000) >> 24])
};
const writeCompactPrimitive_u32 = (out: Buf, value: Primitive_u32) => {
    if (value < 0 || value > 0xffffffff) throw new Error('u32 out of range');
    if (value <= 0b0011_1111) {
        writePrimitive_u8(out, (value << 2));
    } else if (value <= 0b0011_1111_1111_1111) {
        writePrimitive_u16(out, (value << 2) | 0b01);
    } else if (value <= 0b0011_1111_1111_1111_1111_1111_1111_1111) {
        writePrimitive_u32(out, (value << 2) | 0b10);
    } else {
        writePrimitive_u8(out, 0b11);
        writePrimitive_u32(out, value);
    }
}

type Primitive_u64 = bigint;
const _u64Bytes = (value: Primitive_u64) => {
    if (value < 0n || value > 0xffffffffffffffffn) throw new Error('u64 out of range');
    return [
        Number(value & 0xffn),
        Number((value & 0xff00n) >> 8n),
        Number((value & 0xff0000n) >> 16n),
        Number((value & 0xff000000n) >> 24n),
        Number((value & 0xff00000000n) >> 32n),
        Number((value & 0xff0000000000n) >> 40n),
        Number((value & 0xff000000000000n) >> 48n),
        Number((value & 0xff00000000000000n) >> 56n),
    ] as const;
};
const writePrimitive_u64 = (out: Buf, value: Primitive_u64) => putBytes(out, _u64Bytes(value));
const writeCompactPrimitive_u64 = (out: Buf, value: Primitive_u64) => {
    if (value < 0n || value > 0xffffffffffffffffn) throw new Error('u64 out of range');
    if (value < 0b0011_1111n) {
        writePrimitive_u8(out, (Number(value) << 2));
    } else if (value < 0b0011_1111_1111_1111n) {
        writePrimitive_u16(out, (Number(value) << 2) | 0b01);
    } else if (value < 0b0011_1111_1111_1111_1111_1111_1111_1111n) {
        writePrimitive_u32(out, (Number(value) << 2) | 0b10);
    } else {
        const bytes = _u64Bytes(value);
        let bytesNeeded = 8;
        for (let i = 0; i < 8; i++) {
            if (bytes[8 - i] != 0) break;
            bytesNeeded--;
        }
        // assume bytesNeeded >= 4, as other cases are already covered
        writePrimitive_u8(out, 0b11 | ((bytesNeeded - 4) << 2));
        for (let i = 0; i < bytesNeeded; i++) {
            writePrimitive_u8(out, bytes[i]);
        }
    }
}

type Primitive_u128 = bigint;
const _u128Bytes = (value: Primitive_u128) => {
    if (value < 0n || value > 0xffffffffffffffffffffffffffffffffn) throw new Error('u128 out of range');
    return [
        Number(value & 0xffn),
        Number((value & 0xff00n) >> 8n),
        Number((value & 0xff0000n) >> 16n),
        Number((value & 0xff000000n) >> 24n),
        Number((value & 0xff00000000n) >> 32n),
        Number((value & 0xff0000000000n) >> 40n),
        Number((value & 0xff000000000000n) >> 48n),
        Number((value & 0xff00000000000000n) >> 56n),
        Number((value & 0xff0000000000000000n) >> 64n),
        Number((value & 0xff000000000000000000n) >> 72n),
        Number((value & 0xff00000000000000000000n) >> 80n),
        Number((value & 0xff0000000000000000000000n) >> 88n),
        Number((value & 0xff000000000000000000000000n) >> 96n),
        Number((value & 0xff00000000000000000000000000n) >> 104n),
        Number((value & 0xff0000000000000000000000000000n) >> 112n),
        Number((value & 0xff000000000000000000000000000000n) >> 120n),
    ] as const;
};
const writePrimitive_u128 = (out: Buf, value: Primitive_u128) => putBytes(out, _u128Bytes(value));
const writeCompactPrimitive_u128 = (out: Buf, value: Primitive_u128) => {
    if (value < 0n || value > 0xffffffffffffffffffffffffffffffffn) throw new Error('u128 out of range');
    if (value < 0b0011_1111n) {
        writePrimitive_u8(out, (Number(value) << 2));
    } else if (value < 0b0011_1111_1111_1111n) {
        writePrimitive_u16(out, (Number(value) << 2) | 0b01);
    } else if (value < 0b0011_1111_1111_1111_1111_1111_1111_1111n) {
        writePrimitive_u32(out, (Number(value) << 2) | 0b10);
    } else {
        const bytes = _u128Bytes(value);
        let bytesNeeded = 16;
        for (let i = 0; i < 16; i++) {
            if (bytes[16 - i] != 0) break;
            bytesNeeded--;
        }
        // assume bytesNeeded >= 4, as other cases are already covered
        writePrimitive_u8(out, 0b11 | ((bytesNeeded - 4) << 2));
        for (let i = 0; i < bytesNeeded; i++) {
            writePrimitive_u8(out, bytes[i]);
        }
    }
}

type Primitive_str = string;
const writePrimitive_str = (out: Buf, value: Primitive_str) => {
    const bytes = ENCODER.encode(value);
    writeCompactPrimitive_u32(out, bytes.length);
    for (let byte of bytes) {
        writePrimitive_u8(out, byte);
    }
}

/**
 * This code is automatically generated
 */
